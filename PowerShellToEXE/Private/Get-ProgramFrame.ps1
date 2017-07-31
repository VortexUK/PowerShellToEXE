function Get-ProgramFrame
{
    [OutputType([System.String])]
    PARAM
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
        [System.String]$B64InputScript,
        [parameter(Mandatory=$true,
            Position=2,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateSet('STA','MTA')]
        [System.String]$ApartmentType,
        [parameter(Mandatory=$false,
            Position=3,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.Boolean]$NoConsole = $false,
        [parameter(Mandatory=$false,
            Position=4,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.String]$Title,
        [parameter(Mandatory=$false,
            Position=5,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.String]$Description, 
        [parameter(Mandatory=$false,
            Position=6,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.String]$Company = 'CompanyName', 
        [parameter(Mandatory=$false,
            Position=7,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.String]$Product, 
        [parameter(Mandatory=$false,
            Position=8,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.String]$Copyright = '© CompanyName, All rights reserved', 
        [parameter(Mandatory=$false,
            Position=9,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [System.String]$Trademark, 
        [parameter(Mandatory=$false,
            Position=10,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({[System.Version]::TryParse($_,[ref]([System.Version]$null))})]
        [System.String]$Version
    )
    BEGIN 
    {
        # escape escape sequences in version info
        $Title = $Title -replace "\\", "\\"
        $Product = $Product -replace "\\", "\\"
        $Copyright = $Copyright -replace "\\", "\\"
        $Trademark = $Trademark -replace "\\", "\\"
        $Description = $Description -replace "\\", "\\"
        $Company = $Company -replace "\\", "\\"
    }
    PROCESS
    {
        #region Build ProgramFrame
        $programFrame = @"
// Simple PowerShell host created by Ingo Karstein (http://blog.karstein-consulting.com) for PS2EXE
// Reworked and GUI support by Markus Scholtes

using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using PowerShell = System.Management.Automation.PowerShell;
using System.Globalization;
using System.Management.Automation.Host;
using System.Security;
using System.Reflection;
using System.Runtime.InteropServices;
$(if ($NoConsole) {@"
using System.Windows.Forms;
using System.Drawing;
"@ })

[assembly:AssemblyTitle("$title")]
[assembly:AssemblyProduct("$product")]
[assembly:AssemblyCopyright("$copyright")]
[assembly:AssemblyTrademark("$trademark")]
$(if (![string]::IsNullOrEmpty($version)) {@"
[assembly:AssemblyVersion("$version")]
[assembly:AssemblyFileVersion("$version")]
"@ })
// not displayed in details tab of properties dialog, but embedded to file
[assembly:AssemblyDescription("$description")]
[assembly:AssemblyCompany("$company")]

namespace ik.PowerShell
{
$(if ($noConsole) {@"
	internal class CredentialForm
	{
		// http://www.pinvoke.net/default.aspx/credui/CredUnPackAuthenticationBuffer.html
		// http://www.pinvoke.net/default.aspx/credui/CredUIPromptForWindowsCredentials.html
		// http://www.pinvoke.net/default.aspx/credui.creduipromptforcredentials

		[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
		private struct CREDUI_INFO
		{
			public int cbSize;
			public IntPtr hwndParent;
			public string pszMessageText;
			public string pszCaptionText;
			public IntPtr hbmBanner;
		}

		[Flags]
		enum CREDUI_FLAGS
		{
			INCORRECT_PASSWORD = 0x1,
			DO_NOT_PERSIST = 0x2,
			REQUEST_ADMINISTRATOR = 0x4,
			EXCLUDE_CERTIFICATES = 0x8,
			REQUIRE_CERTIFICATE = 0x10,
			SHOW_SAVE_CHECK_BOX = 0x40,
			ALWAYS_SHOW_UI = 0x80,
			REQUIRE_SMARTCARD = 0x100,
			PASSWORD_ONLY_OK = 0x200,
			VALIDATE_USERNAME = 0x400,
			COMPLETE_USERNAME = 0x800,
			PERSIST = 0x1000,
			SERVER_CREDENTIAL = 0x4000,
			EXPECT_CONFIRMATION = 0x20000,
			GENERIC_CREDENTIALS = 0x40000,
			USERNAME_TARGET_CREDENTIALS = 0x80000,
			KEEP_USERNAME = 0x100000,
		}

		public enum CredUIReturnCodes
		{
			NO_ERROR = 0,
			ERROR_CANCELLED = 1223,
			ERROR_NO_SUCH_LOGON_SESSION = 1312,
			ERROR_NOT_FOUND = 1168,
			ERROR_INVALID_ACCOUNT_NAME = 1315,
			ERROR_INSUFFICIENT_BUFFER = 122,
			ERROR_INVALID_PARAMETER = 87,
			ERROR_INVALID_FLAGS = 1004,
		}

		[DllImport("credui")]
		private static extern CredUIReturnCodes CredUIPromptForCredentials(ref CREDUI_INFO creditUR,
			string targetName,
			IntPtr reserved1,
			int iError,
			StringBuilder userName,
			int maxUserName,
			StringBuilder password,
			int maxPassword,
			[MarshalAs(UnmanagedType.Bool)] ref bool pfSave,
			CREDUI_FLAGS flags);

		public class UserPwd
		{
			public string User = string.Empty;
			public string Password = string.Empty;
			public string Domain = string.Empty;
		}

		internal static UserPwd PromptForPassword(string caption, string message, string target, string user, PSCredentialTypes credTypes, PSCredentialUIOptions options)
		{
			// Setup the flags and variables
			StringBuilder userPassword = new StringBuilder(), userID = new StringBuilder(user, 128);
			CREDUI_INFO credUI = new CREDUI_INFO();
			credUI.cbSize = Marshal.SizeOf(credUI);
			bool save = false;

			CREDUI_FLAGS flags = CREDUI_FLAGS.DO_NOT_PERSIST;
			if ((credTypes & PSCredentialTypes.Domain) != PSCredentialTypes.Domain)
			{
				flags |= CREDUI_FLAGS.GENERIC_CREDENTIALS;
				if ((options & PSCredentialUIOptions.AlwaysPrompt) == PSCredentialUIOptions.AlwaysPrompt)
				{
					flags |= CREDUI_FLAGS.ALWAYS_SHOW_UI;
				}
			}

			// Prompt the user
			CredUIReturnCodes returnCode = CredUIPromptForCredentials(ref credUI, target, IntPtr.Zero, 0, userID, 128, userPassword, 128, ref save, flags);

			if (returnCode == CredUIReturnCodes.NO_ERROR)
			{
				UserPwd ret = new UserPwd();
				ret.User = userID.ToString();
				ret.Password = userPassword.ToString();
				ret.Domain = "";
				return ret;
			}

			return null;
		}
	}
"@ })

	internal class PS2EXEHostRawUI : PSHostRawUserInterface
	{
$(if ($noConsole){ @"
		// Speicher für Konsolenfarben bei GUI-Output werden gelesen und gesetzt, aber im Moment nicht genutzt (for future use)
		private ConsoleColor ncBackgroundColor = ConsoleColor.White;
		private ConsoleColor ncForegroundColor = ConsoleColor.Black;
"@ } else {@"
		const int STD_OUTPUT_HANDLE = -11;

		//CHAR_INFO struct, which was a union in the old days
		// so we want to use LayoutKind.Explicit to mimic it as closely
		// as we can
		[StructLayout(LayoutKind.Explicit)]
		public struct CHAR_INFO
		{
			[FieldOffset(0)]
			internal char UnicodeChar;
			[FieldOffset(0)]
			internal char AsciiChar;
			[FieldOffset(2)] //2 bytes seems to work properly
			internal UInt16 Attributes;
		}

		//COORD struct
		[StructLayout(LayoutKind.Sequential)]
		public struct COORD
		{
			public short X;
			public short Y;
		}

		//SMALL_RECT struct
		[StructLayout(LayoutKind.Sequential)]
		public struct SMALL_RECT
		{
			public short Left;
			public short Top;
			public short Right;
			public short Bottom;
		}

		/* Reads character and color attribute data from a rectangular block of character cells in a console screen buffer,
			 and the function writes the data to a rectangular block at a specified location in the destination buffer. */
		[DllImport("kernel32.dll", EntryPoint = "ReadConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]
		internal static extern bool ReadConsoleOutput(
			IntPtr hConsoleOutput,
			/* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures
			whose size is specified by the dwBufferSize parameter.*/
			[MarshalAs(UnmanagedType.LPArray), Out] CHAR_INFO[,] lpBuffer,
			COORD dwBufferSize,
			COORD dwBufferCoord,
			ref SMALL_RECT lpReadRegion);

		/* Writes character and color attribute data to a specified rectangular block of character cells in a console screen buffer.
			The data to be written is taken from a correspondingly sized rectangular block at a specified location in the source buffer */
		[DllImport("kernel32.dll", EntryPoint = "WriteConsoleOutputW", CharSet = CharSet.Unicode, SetLastError = true)]
		internal static extern bool WriteConsoleOutput(
			IntPtr hConsoleOutput,
			/* This pointer is treated as the origin of a two-dimensional array of CHAR_INFO structures
			whose size is specified by the dwBufferSize parameter.*/
			[MarshalAs(UnmanagedType.LPArray), In] CHAR_INFO[,] lpBuffer,
			COORD dwBufferSize,
			COORD dwBufferCoord,
			ref SMALL_RECT lpWriteRegion);

		/* Moves a block of data in a screen buffer. The effects of the move can be limited by specifying a clipping rectangle, so
			the contents of the console screen buffer outside the clipping rectangle are unchanged. */
		[DllImport("kernel32.dll", SetLastError = true)]
		static extern bool ScrollConsoleScreenBuffer(
			IntPtr hConsoleOutput,
			[In] ref SMALL_RECT lpScrollRectangle,
			[In] ref SMALL_RECT lpClipRectangle,
			COORD dwDestinationOrigin,
			[In] ref CHAR_INFO lpFill);

		[DllImport("kernel32.dll", SetLastError = true)]
			static extern IntPtr GetStdHandle(int nStdHandle);
"@ })

		public override ConsoleColor BackgroundColor
		{
$(if (!$noConsole){ @"
			get
			{
				return Console.BackgroundColor;
			}
			set
			{
				Console.BackgroundColor = value;
			}
"@ } else {@"
			get
			{
				return ncBackgroundColor;
			}
			set
			{
				ncBackgroundColor = value;
			}
"@ })
		}

		public override System.Management.Automation.Host.Size BufferSize
		{
			get
			{
$(if (!$noConsole){ @"
					return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferHeight);
"@ } else {@"
					// return default value for Winforms. If no valid value is returned WriteLine will not be called
					return new System.Management.Automation.Host.Size(120, 50);
"@ })
			}
			set
			{
$(if (!$noConsole){ @"
				Console.BufferWidth = value.Width;
				Console.BufferHeight = value.Height;
"@ })
			}
		}

		public override Coordinates CursorPosition
		{
			get
			{
$(if (!$noConsole){ @"
				return new Coordinates(Console.CursorLeft, Console.CursorTop);
"@ } else {@"
				// Dummywert für Winforms zurückgeben.
				return new Coordinates(0, 0);
"@ })
			}
			set
			{
$(if (!$noConsole){ @"
				Console.CursorTop = value.Y;
				Console.CursorLeft = value.X;
"@ })
			}
		}

		public override int CursorSize
		{
			get
			{
$(if (!$noConsole){ @"
				return Console.CursorSize;
"@ } else {@"
				// Dummywert für Winforms zurückgeben.
				return 25;
"@ })
			}
			set
			{
$(if (!$noConsole){ @"
				Console.CursorSize = value;
"@ })
			}
		}

		public override void FlushInputBuffer()
		{
			// Nothing to do
		}

		public override ConsoleColor ForegroundColor
		{
$(if (!$noConsole){ @"
			get
			{
				return Console.ForegroundColor;
			}
			set
			{
				Console.ForegroundColor = value;
			}
"@ } else {@"
			get
			{
				return ncForegroundColor;
			}
			set
			{
				ncForegroundColor = value;
			}
"@ })
		}

		public override BufferCell[,] GetBufferContents(System.Management.Automation.Host.Rectangle rectangle)
		{
$(if (!$noConsole) {@"
			IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
			CHAR_INFO[,] buffer = new CHAR_INFO[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];
			COORD buffer_size = new COORD() {X = (short)(rectangle.Right - rectangle.Left + 1), Y = (short)(rectangle.Bottom - rectangle.Top + 1)};
			COORD buffer_index = new COORD() {X = 0, Y = 0};
			SMALL_RECT screen_rect = new SMALL_RECT() {Left = (short)rectangle.Left, Top = (short)rectangle.Top, Right = (short)rectangle.Right, Bottom = (short)rectangle.Bottom};

			ReadConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);

			System.Management.Automation.Host.BufferCell[,] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];
			for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)
				for (int x = 0; x <= rectangle.Right - rectangle.Left; x++)
				{
					ScreenBuffer[y,x] = new System.Management.Automation.Host.BufferCell(buffer[y,x].AsciiChar, (System.ConsoleColor)(buffer[y,x].Attributes & 0xF), (System.ConsoleColor)((buffer[y,x].Attributes & 0xF0) / 0x10), System.Management.Automation.Host.BufferCellType.Complete);
				}

			return ScreenBuffer;
"@ } else {@"
			System.Management.Automation.Host.BufferCell[,] ScreenBuffer = new System.Management.Automation.Host.BufferCell[rectangle.Bottom - rectangle.Top + 1, rectangle.Right - rectangle.Left + 1];

			for (int y = 0; y <= rectangle.Bottom - rectangle.Top; y++)
				for (int x = 0; x <= rectangle.Right - rectangle.Left; x++)
				{
					ScreenBuffer[y,x] = new System.Management.Automation.Host.BufferCell(' ', ncForegroundColor, ncBackgroundColor, System.Management.Automation.Host.BufferCellType.Complete);
				}

			return ScreenBuffer;
"@ } )
		}

		public override bool KeyAvailable
		{
			get
			{
$(if (!$noConsole) {@"
				return Console.KeyAvailable;
"@ } else {@"
				return true;
"@ })
			}
		}

		public override System.Management.Automation.Host.Size MaxPhysicalWindowSize
		{
			get
			{
$(if (!$noConsole){ @"
				return new System.Management.Automation.Host.Size(Console.LargestWindowWidth, Console.LargestWindowHeight);
"@ } else {@"
				// Dummy-Wert für Winforms
				return new System.Management.Automation.Host.Size(240, 84);
"@ })
			}
		}

		public override System.Management.Automation.Host.Size MaxWindowSize
		{
			get
			{
$(if (!$noConsole){ @"
				return new System.Management.Automation.Host.Size(Console.BufferWidth, Console.BufferWidth);
"@ } else {@"
				// Dummy-Wert für Winforms
				return new System.Management.Automation.Host.Size(120, 84);
"@ })
			}
		}

		public override KeyInfo ReadKey(ReadKeyOptions options)
		{
$(if (!$noConsole) {@"
			ConsoleKeyInfo cki = Console.ReadKey((options & ReadKeyOptions.NoEcho)!=0);

			ControlKeyStates cks = 0;
			if ((cki.Modifiers & ConsoleModifiers.Alt) != 0)
				cks |= ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
			if ((cki.Modifiers & ConsoleModifiers.Control) != 0)
				cks |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
			if ((cki.Modifiers & ConsoleModifiers.Shift) != 0)
				cks |= ControlKeyStates.ShiftPressed;
			if (Console.CapsLock)
				cks |= ControlKeyStates.CapsLockOn;
			if (Console.NumberLock)
				cks |= ControlKeyStates.NumLockOn;

			return new KeyInfo((int)cki.Key, cki.KeyChar, cks, (options & ReadKeyOptions.IncludeKeyDown)!=0);
"@ } else {@"
			if ((options & ReadKeyOptions.IncludeKeyDown)!=0)
				return ReadKeyBox.Show("", "", true);
			else
				return ReadKeyBox.Show("", "", false);
"@ })
		}

		public override void ScrollBufferContents(System.Management.Automation.Host.Rectangle source, Coordinates destination, System.Management.Automation.Host.Rectangle clip, BufferCell fill)
		{ // no destination block clipping implemented
$(if (!$noConsole) { @"
			// clip area out of source range?
			if ((source.Left > clip.Right) || (source.Right < clip.Left) || (source.Top > clip.Bottom) || (source.Bottom < clip.Top))
			{ // clipping out of range -> nothing to do
				return;
			}

			IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
			SMALL_RECT lpScrollRectangle = new SMALL_RECT() {Left = (short)source.Left, Top = (short)source.Top, Right = (short)(source.Right), Bottom = (short)(source.Bottom)};
			SMALL_RECT lpClipRectangle;
			if (clip != null)
			{ lpClipRectangle = new SMALL_RECT() {Left = (short)clip.Left, Top = (short)clip.Top, Right = (short)(clip.Right), Bottom = (short)(clip.Bottom)}; }
			else
			{ lpClipRectangle = new SMALL_RECT() {Left = (short)0, Top = (short)0, Right = (short)(Console.WindowWidth - 1), Bottom = (short)(Console.WindowHeight - 1)}; }
			COORD dwDestinationOrigin = new COORD() {X = (short)(destination.X), Y = (short)(destination.Y)};
			CHAR_INFO lpFill = new CHAR_INFO() { AsciiChar = fill.Character, Attributes = (ushort)((int)(fill.ForegroundColor) + (int)(fill.BackgroundColor)*16) };

			ScrollConsoleScreenBuffer(hStdOut, ref lpScrollRectangle, ref lpClipRectangle, dwDestinationOrigin, ref lpFill);
"@  })
		}

		public override void SetBufferContents(System.Management.Automation.Host.Rectangle rectangle, BufferCell fill)
		{
$(if (!$noConsole){ @"
			// using a trick: move the buffer out of the screen, the source area gets filled with the char fill.Character
			if (rectangle.Left >= 0)
				Console.MoveBufferArea(rectangle.Left, rectangle.Top, rectangle.Right-rectangle.Left+1, rectangle.Bottom-rectangle.Top+1, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);
			else
			{ // Clear-Host: move all content off the screen
				Console.MoveBufferArea(0, 0, BufferSize.Width, BufferSize.Height, BufferSize.Width, BufferSize.Height, fill.Character, fill.ForegroundColor, fill.BackgroundColor);
			}
"@ })
		}

		public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)
		{
$(if (!$noConsole) { @"
			IntPtr hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
			CHAR_INFO[,] buffer = new CHAR_INFO[contents.GetLength(0), contents.GetLength(1)];
			COORD buffer_size = new COORD() {X = (short)(contents.GetLength(1)), Y = (short)(contents.GetLength(0))};
			COORD buffer_index = new COORD() {X = 0, Y = 0};
			SMALL_RECT screen_rect = new SMALL_RECT() {Left = (short)origin.X, Top = (short)origin.Y, Right = (short)(origin.X + contents.GetLength(1) - 1), Bottom = (short)(origin.Y + contents.GetLength(0) - 1)};

			for (int y = 0; y < contents.GetLength(0); y++)
				for (int x = 0; x < contents.GetLength(1); x++)
				{
					buffer[y,x] = new CHAR_INFO() { AsciiChar = contents[y,x].Character, Attributes = (ushort)((int)(contents[y,x].ForegroundColor) + (int)(contents[y,x].BackgroundColor)*16) };
				}

			WriteConsoleOutput(hStdOut, buffer, buffer_size, buffer_index, ref screen_rect);
"@  })
		}

		public override Coordinates WindowPosition
		{
			get
			{
				Coordinates s = new Coordinates();
$(if (!$noConsole){ @"
				s.X = Console.WindowLeft;
				s.Y = Console.WindowTop;
"@ } else {@"
				// Dummy-Wert für Winforms
				s.X = 0;
				s.Y = 0;
"@ })
				return s;
			}
			set
			{
$(if (!$noConsole){ @"
				Console.WindowLeft = value.X;
				Console.WindowTop = value.Y;
"@ })
			}
		}

		public override System.Management.Automation.Host.Size WindowSize
		{
			get
			{
				System.Management.Automation.Host.Size s = new System.Management.Automation.Host.Size();
$(if (!$noConsole){ @"
				s.Height = Console.WindowHeight;
				s.Width = Console.WindowWidth;
"@ } else {@"
				// Dummy-Wert für Winforms
				s.Height = 50;
				s.Width = 120;
"@ })
				return s;
			}
			set
			{
$(if (!$noConsole){ @"
				Console.WindowWidth = value.Width;
				Console.WindowHeight = value.Height;
"@ })
			}
		}

		public override string WindowTitle
		{
			get
			{
$(if (!$noConsole){ @"
				return Console.Title;
"@ } else {@"
				return System.AppDomain.CurrentDomain.FriendlyName;
"@ })
			}
			set
			{
$(if (!$noConsole){ @"
				Console.Title = value;
"@ })
			}
		}
	}

$(if ($noConsole){ @"
	public class InputBox
	{
		[DllImport("user32.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
 		private static extern IntPtr MB_GetString(uint strId);

		public static DialogResult Show(string sTitle, string sPrompt, ref string sValue, bool bSecure)
		{
		  // Generate controls
			Form form = new Form();
			Label label = new Label();
			TextBox textBox = new TextBox();
			Button buttonOk = new Button();
			Button buttonCancel = new Button();

		  // Sizes and positions are defined according to the label
		  // This control has to be finished first
			if (string.IsNullOrEmpty(sPrompt))
			{
				if (bSecure)
					label.Text = "Secure input:   ";
				else
					label.Text = "Input:          ";
			}
			else
				label.Text = sPrompt;
			label.Location = new Point(9, 19);
			label.AutoSize = true;
		  // Size of the label is defined not before Add()
			form.Controls.Add(label);

		  // Generate textbox
			if (bSecure) textBox.UseSystemPasswordChar = true;
			textBox.Text = sValue;
			textBox.SetBounds(12, label.Bottom, label.Right - 12, 20);

		  // Generate buttons
		  // get localized "OK"-string
		  string sTextOK = Marshal.PtrToStringUni(MB_GetString(0));
			if (string.IsNullOrEmpty(sTextOK))
				buttonOk.Text = "OK";
			else
				buttonOk.Text = sTextOK;

		  // get localized "Cancel"-string
		  string sTextCancel = Marshal.PtrToStringUni(MB_GetString(1));
			if (string.IsNullOrEmpty(sTextCancel))
		  	buttonCancel.Text = "Cancel";
			else
		  	buttonCancel.Text = sTextCancel;

			buttonOk.DialogResult = DialogResult.OK;
			buttonCancel.DialogResult = DialogResult.Cancel;
			buttonOk.SetBounds(System.Math.Max(12, label.Right - 158), label.Bottom + 36, 75, 23);
			buttonCancel.SetBounds(System.Math.Max(93, label.Right - 77), label.Bottom + 36, 75, 23);

		  // Configure form
			if (string.IsNullOrEmpty(sTitle))
				form.Text = System.AppDomain.CurrentDomain.FriendlyName;
			else
				form.Text = sTitle;
			form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 71);
			form.Controls.AddRange(new Control[] { textBox, buttonOk, buttonCancel });
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.AcceptButton = buttonOk;
			form.CancelButton = buttonCancel;

		  // Show form and compute results
			DialogResult dialogResult = form.ShowDialog();
			sValue = textBox.Text;
			return dialogResult;
		}

		public static DialogResult Show(string sTitle, string sPrompt, ref string sValue)
		{
			return Show(sTitle, sPrompt, ref sValue, false);
		}
	}

	public class ChoiceBox
	{
		public static int Show(System.Collections.ObjectModel.Collection<ChoiceDescription> aAuswahl, int iVorgabe, string sTitle, string sPrompt)
		{
			// cancel if array is empty
			if (aAuswahl == null) return -1;
			if (aAuswahl.Count < 1) return -1;

			// Generate controls
			Form form = new Form();
			RadioButton[] aradioButton = new RadioButton[aAuswahl.Count];
			ToolTip toolTip = new ToolTip();
			Button buttonOk = new Button();

		  // Sizes and positions are defined according to the label
		  // This control has to be finished first when a prompt is available
			int iPosY = 19, iMaxX = 0;
			if (!string.IsNullOrEmpty(sPrompt))
			{
				Label label = new Label();
				label.Text = sPrompt;
				label.Location = new Point(9, 19);
				label.AutoSize = true;
				// erst durch Add() wird die Größe des Labels ermittelt
				form.Controls.Add(label);
				iPosY = label.Bottom;
				iMaxX = label.Right;
			}

			// An den Radiobuttons orientieren sich die weiteren Größen und Positionen
			// Diese Controls also jetzt fertigstellen
			int Counter = 0;
			foreach (ChoiceDescription sAuswahl in aAuswahl)
			{
				aradioButton[Counter] = new RadioButton();
				aradioButton[Counter].Text = sAuswahl.Label;
				if (Counter == iVorgabe)
				{ aradioButton[Counter].Checked = true; }
				aradioButton[Counter].Location = new Point(9, iPosY);
				aradioButton[Counter].AutoSize = true;
				// erst durch Add() wird die Größe des Labels ermittelt
				form.Controls.Add(aradioButton[Counter]);
				iPosY = aradioButton[Counter].Bottom;
				if (aradioButton[Counter].Right > iMaxX) { iMaxX = aradioButton[Counter].Right; }
				if (!string.IsNullOrEmpty(sAuswahl.HelpMessage))
				{
					 toolTip.SetToolTip(aradioButton[Counter], sAuswahl.HelpMessage);
				}
				Counter++;
			}

			// Tooltip auch anzeigen, wenn Parent-Fenster inaktiv ist
			toolTip.ShowAlways = true;

			// Button erzeugen
			buttonOk.Text = "OK";
			buttonOk.DialogResult = DialogResult.OK;
			buttonOk.SetBounds(System.Math.Max(12, iMaxX - 77), iPosY + 36, 75, 23);

			// configure form
			if (string.IsNullOrEmpty(sTitle))
				form.Text = System.AppDomain.CurrentDomain.FriendlyName;
			else
				form.Text = sTitle;
			form.ClientSize = new System.Drawing.Size(System.Math.Max(178, iMaxX + 10), iPosY + 71);
			form.Controls.Add(buttonOk);
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			form.MinimizeBox = false;
			form.MaximizeBox = false;
			form.AcceptButton = buttonOk;

			// show and compute form
			if (form.ShowDialog() == DialogResult.OK)
			{ int iRueck = -1;
				for (Counter = 0; Counter < aAuswahl.Count; Counter++)
				{
					if (aradioButton[Counter].Checked == true)
					{ iRueck = Counter; }
				}
				return iRueck;
			}
			else
				return -1;
		}
	}

	public class ReadKeyBox
	{
		[DllImport("user32.dll")]
		public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,
			[Out, MarshalAs(UnmanagedType.LPWStr, SizeConst = 64)] System.Text.StringBuilder pwszBuff,
			int cchBuff, uint wFlags);

		static string GetCharFromKeys(Keys keys, bool bShift, bool bAltGr)
		{
			System.Text.StringBuilder buffer = new System.Text.StringBuilder(64);
			byte[] keyboardState = new byte[256];
			if (bShift)
			{ keyboardState[(int) Keys.ShiftKey] = 0xff; }
			if (bAltGr)
			{ keyboardState[(int) Keys.ControlKey] = 0xff;
				keyboardState[(int) Keys.Menu] = 0xff;
			}
			if (ToUnicode((uint) keys, 0, keyboardState, buffer, 64, 0) >= 1)
				return buffer.ToString();
			else
				return "\0";
		}

		class KeyboardForm : Form
		{
			public KeyboardForm()
			{
				this.KeyDown += new KeyEventHandler(KeyboardForm_KeyDown);
				this.KeyUp += new KeyEventHandler(KeyboardForm_KeyUp);
			}

			// check for KeyDown or KeyUp?
			public bool checkKeyDown = true;
			// key code for pressed key
			public KeyInfo keyinfo;

			void KeyboardForm_KeyDown(object sender, KeyEventArgs e)
			{
				if (checkKeyDown)
				{ // store key info
					keyinfo.VirtualKeyCode = e.KeyValue;
					keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];
					keyinfo.KeyDown = false;
					keyinfo.ControlKeyState = 0;
					if (e.Alt) { keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed; }
					if (e.Control)
					{ keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
						if (!e.Alt)
						{ if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64); }
					}
					if (e.Shift) { keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed; }
					if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn; }
					if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn; }
					// and close the form
					this.Close();
				}
			}

			void KeyboardForm_KeyUp(object sender, KeyEventArgs e)
			{
				if (!checkKeyDown)
				{ // store key info
					keyinfo.VirtualKeyCode = e.KeyValue;
					keyinfo.Character = GetCharFromKeys(e.KeyCode, e.Shift, e.Alt & e.Control)[0];
					keyinfo.KeyDown = true;
					keyinfo.ControlKeyState = 0;
					if (e.Alt) { keyinfo.ControlKeyState = ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed; }
					if (e.Control)
					{ keyinfo.ControlKeyState |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
						if (!e.Alt)
						{ if (e.KeyValue > 64 && e.KeyValue < 96) keyinfo.Character = (char)(e.KeyValue - 64); }
					}
					if (e.Shift) { keyinfo.ControlKeyState |= ControlKeyStates.ShiftPressed; }
					if ((e.Modifiers & System.Windows.Forms.Keys.CapsLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.CapsLockOn; }
					if ((e.Modifiers & System.Windows.Forms.Keys.NumLock) > 0) { keyinfo.ControlKeyState |= ControlKeyStates.NumLockOn; }
					// and close the form
					this.Close();
				}
			}
		}

		public static KeyInfo Show(string sTitle, string sPrompt, bool bIncludeKeyDown)
		{
			// Controls erzeugen
			KeyboardForm form = new KeyboardForm();
			Label label = new Label();

			// Am Label orientieren sich die Größen und Positionen
			// Dieses Control also zuerst fertigstellen
			if (string.IsNullOrEmpty(sPrompt))
			{
					label.Text = "Press a key";
			}
			else
				label.Text = sPrompt;
			label.Location = new Point(9, 19);
			label.AutoSize = true;
			// erst durch Add() wird die Größe des Labels ermittelt
			form.Controls.Add(label);

			// configure form
			if (string.IsNullOrEmpty(sTitle))
				form.Text = System.AppDomain.CurrentDomain.FriendlyName;
			else
				form.Text = sTitle;
			form.ClientSize = new System.Drawing.Size(System.Math.Max(178, label.Right + 10), label.Bottom + 55);
			form.FormBorderStyle = FormBorderStyle.FixedDialog;
			form.StartPosition = FormStartPosition.CenterScreen;
			form.MinimizeBox = false;
			form.MaximizeBox = false;

			// show and compute form
			form.checkKeyDown = bIncludeKeyDown;
			form.ShowDialog();
			return form.keyinfo;
		}
	}

	public class ProgressForm : Form
	{
		private Label objLblActivity;
		private Label objLblStatus;
		private ProgressBar objProgressBar;
		private Label objLblRemainingTime;
		private Label objLblOperation;

		private void InitializeComponent()
		{
			this.objLblActivity = new Label();
			this.objLblStatus = new Label();
			this.objProgressBar = new ProgressBar();
			this.objLblRemainingTime = new Label();
			this.objLblOperation = new Label();

			this.SuspendLayout();

			this.Text = "Progress";
			this.Height = 160;
			this.Width = 800;
			this.BackColor = Color.White;
			this.FormBorderStyle = FormBorderStyle.FixedSingle;
			this.ControlBox = false;
			this.StartPosition = FormStartPosition.CenterScreen;

			// Create Label
			objLblActivity = new Label();
			objLblActivity.Left = 5;
			objLblActivity.Top = 10;
			objLblActivity.Width = 800 - 20;
			objLblActivity.Height = 16;
			objLblActivity.Font = new Font(objLblActivity.Font, FontStyle.Bold);
			objLblActivity.Text = "";
			// Add Label to Form
			this.Controls.Add(objLblActivity);

			// Create Label
			objLblStatus = new Label();
			objLblStatus.Left = 25;
			objLblStatus.Top = 26;
			objLblStatus.Width = 800 - 40;
			objLblStatus.Height = 16;
			objLblStatus.Text = "";
			// Add Label to Form
			this.Controls.Add(objLblStatus);

			// Create ProgressBar
			objProgressBar = new ProgressBar();
			objProgressBar.Value = 0;
			objProgressBar.Style = ProgressBarStyle.Continuous;
			objProgressBar.Size = new System.Drawing.Size(800 - 60, 20);
			objProgressBar.Left = 25;
			objProgressBar.Top = 55;
			// Add ProgressBar to Form
			this.Controls.Add(objProgressBar);

			// Create Label
			objLblRemainingTime = new Label();
			objLblRemainingTime.Left = 5;
			objLblRemainingTime.Top = 85;
			objLblRemainingTime.Width = 800 - 20;
			objLblRemainingTime.Height = 16;
			objLblRemainingTime.Text = "";
			// Add Label to Form
			this.Controls.Add(objLblRemainingTime);

			// Create Label
			objLblOperation = new Label();
			objLblOperation.Left = 25;
			objLblOperation.Top = 101;
			objLblOperation.Width = 800 - 40;
			objLblOperation.Height = 16;
			objLblOperation.Text = "";
			// Add Label to Form
			this.Controls.Add(objLblOperation);

			this.ResumeLayout();
		}

		public ProgressForm()
		{
			InitializeComponent();
		}

		public void Update(ProgressRecord objRecord)
		{
			if (objRecord == null)
				return;

			if (objRecord.RecordType == ProgressRecordType.Completed)
			{
				this.Close();
				return;
			}

			if (!string.IsNullOrEmpty(objRecord.Activity))
				objLblActivity.Text = objRecord.Activity;
			else
				objLblActivity.Text = "";

			if (!string.IsNullOrEmpty(objRecord.StatusDescription))
				objLblStatus.Text = objRecord.StatusDescription;
			else
				objLblStatus.Text = "";

			if ((objRecord.PercentComplete >= 0) && (objRecord.PercentComplete <= 100))
			{
				objProgressBar.Value = objRecord.PercentComplete;
				objProgressBar.Visible = true;
			}
			else
			{ if (objRecord.PercentComplete > 100)
				{
					objProgressBar.Value = 0;
					objProgressBar.Visible = true;
				}
				else
					objProgressBar.Visible = false;
			}

			if (objRecord.SecondsRemaining >= 0)
			{
				System.TimeSpan objTimeSpan = new System.TimeSpan(0, 0, objRecord.SecondsRemaining);
				objLblRemainingTime.Text = "Remaining time: " + string.Format("{0:00}:{1:00}:{2:00}", (int)objTimeSpan.TotalHours, objTimeSpan.Minutes, objTimeSpan.Seconds);
			}
			else
				objLblRemainingTime.Text = "";

			if (!string.IsNullOrEmpty(objRecord.CurrentOperation))
				objLblOperation.Text = objRecord.CurrentOperation;
			else
				objLblOperation.Text = "";

			this.Refresh();
			Application.DoEvents();
		}
	}
"@ })

	internal class PS2EXEHostUI : PSHostUserInterface
	{

		private PS2EXEHostRawUI rawUI = null;

		public PS2EXEHostUI() : base()
		{
			rawUI = new PS2EXEHostRawUI();
$(if (!$noConsole) {@"
			rawUI.ForegroundColor = Console.ForegroundColor;
			rawUI.BackgroundColor = Console.BackgroundColor;
"@ })
		}

		public override Dictionary<string, PSObject> Prompt(string caption, string message, System.Collections.ObjectModel.Collection<FieldDescription> descriptions)
		{
$(if (!$noConsole) {@"
			if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
			if (!string.IsNullOrEmpty(message)) WriteLine(message);
"@ } else {@"
			if ((!string.IsNullOrEmpty(caption)) || (!string.IsNullOrEmpty(message)))
			{ string sTitel = System.AppDomain.CurrentDomain.FriendlyName, sMeldung = "";

				if (!string.IsNullOrEmpty(caption)) sTitel = caption;
				if (!string.IsNullOrEmpty(message)) sMeldung = message;
				MessageBox.Show(sMeldung, sTitel);
			}

			// Titel und Labeltext für Inputbox zurücksetzen
			ibcaption = "";
			ibmessage = "";
"@ })
			Dictionary<string, PSObject> ret = new Dictionary<string, PSObject>();
			foreach (FieldDescription cd in descriptions)
			{
				Type t = null;
				if (string.IsNullOrEmpty(cd.ParameterAssemblyFullName))
					t = typeof(string);
				else
					t = Type.GetType(cd.ParameterAssemblyFullName);

				if (t.IsArray)
				{
					Type elementType = t.GetElementType();
					Type genericListType = Type.GetType("System.Collections.Generic.List"+((char)0x60).ToString()+"1");
					genericListType = genericListType.MakeGenericType(new Type[] { elementType });
					ConstructorInfo constructor = genericListType.GetConstructor(BindingFlags.CreateInstance | BindingFlags.Instance | BindingFlags.Public, null, Type.EmptyTypes, null);
					object resultList = constructor.Invoke(null);

					int index = 0;
					string data = "";
					do
					{
						try
						{
$(if (!$noConsole) {@"
							if (!string.IsNullOrEmpty(cd.Name)) Write(string.Format("{0}[{1}]: ", cd.Name, index));
"@ } else {@"
							if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}[{1}]: ", cd.Name, index);
"@ })
							data = ReadLine();
							if (string.IsNullOrEmpty(data))
								break;

							object o = System.Convert.ChangeType(data, elementType);
							genericListType.InvokeMember("Add", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, new object[] { o });
						}
						catch (Exception e)
						{
							throw e;
						}
						index++;
					} while (true);

					System.Array retArray = (System.Array )genericListType.InvokeMember("ToArray", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, null);
					ret.Add(cd.Name, new PSObject(retArray));
				}
				else
				{
					object o = null;
					string l = null;
					try
					{
						if (t != typeof(System.Security.SecureString))
						{
							if (t != typeof(System.Management.Automation.PSCredential))
							{
$(if (!$noConsole) {@"
								if (!string.IsNullOrEmpty(cd.Name)) Write(cd.Name);
								if (!string.IsNullOrEmpty(cd.HelpMessage)) Write(" (Type !? for help.)");
								if ((!string.IsNullOrEmpty(cd.Name)) || (!string.IsNullOrEmpty(cd.HelpMessage))) Write(": ");
"@ } else {@"
								if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}: ", cd.Name);
								if (!string.IsNullOrEmpty(cd.HelpMessage)) ibmessage += "\n(Type !? for help.)";
"@ })
								do {
									l = ReadLine();
									if (l == "!?")
										WriteLine(cd.HelpMessage);
									else
									{
										if (string.IsNullOrEmpty(l)) o = cd.DefaultValue;
										if (o == null)
										{
											try {
												o = System.Convert.ChangeType(l, t);
											}
											catch {
												Write("Wrong format, please repeat input: ");
												l = "!?";
											}
										}
									}
								} while (l == "!?");
							}
							else
							{
								PSCredential pscred = PromptForCredential("", "", "", "");
								o = pscred;
							}
						}
						else
						{
$(if (!$noConsole) {@"
								if (!string.IsNullOrEmpty(cd.Name)) Write(string.Format("{0}: ", cd.Name));
"@ } else {@"
								if (!string.IsNullOrEmpty(cd.Name)) ibmessage = string.Format("{0}: ", cd.Name);
"@ })

							SecureString pwd = null;
							pwd = ReadLineAsSecureString();
							o = pwd;
						}

						ret.Add(cd.Name, new PSObject(o));
					}
					catch (Exception e)
					{
						throw e;
					}
				}
			}
$(if ($noConsole) {@"
			// Titel und Labeltext für Inputbox zurücksetzen
			ibcaption = "";
			ibmessage = "";
"@ })
			return ret;
		}

		public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice)
		{
$(if ($noConsole) {@"
			int iReturn = ChoiceBox.Show(choices, defaultChoice, caption, message);
			if (iReturn == -1) { iReturn = defaultChoice; }
			return iReturn;
"@ } else {@"
			if (!string.IsNullOrEmpty(caption))
				WriteLine(caption);
			WriteLine(message);
			int idx = 0;
			SortedList<string, int> res = new SortedList<string, int>();
			foreach (ChoiceDescription cd in choices)
			{
				string lkey = cd.Label.Substring(0, 1), ltext = cd.Label;
				int pos = cd.Label.IndexOf('&');
				if (pos > -1)
				{
					lkey = cd.Label.Substring(pos + 1, 1).ToUpper();
					if (pos > 0)
						ltext = cd.Label.Substring(0, pos) + cd.Label.Substring(pos + 1);
					else
						ltext = cd.Label.Substring(1);
				}
				res.Add(lkey.ToLower(), idx);

				if (idx > 0) Write("  ");
				if (idx == defaultChoice)
				{
					Write(ConsoleColor.Yellow, Console.BackgroundColor, string.Format("[{0}] {1}", lkey, ltext));
					if (!string.IsNullOrEmpty(cd.HelpMessage))
						Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format(" ({0})", cd.HelpMessage));
				}
				else
				{
					Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format("[{0}] {1}", lkey, ltext));
					if (!string.IsNullOrEmpty(cd.HelpMessage))
						Write(ConsoleColor.Gray, Console.BackgroundColor, string.Format(" ({0})", cd.HelpMessage));
				}
				idx++;
			}
			Write(": ");

			try
			{
				while (true)
				{ string s = Console.ReadLine().ToLower();
					if (res.ContainsKey(s))
						return res[s];
					if (string.IsNullOrEmpty(s))
						return defaultChoice;
				}
			}
			catch { }

			return defaultChoice;
"@ })
		}

		public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
		{
$(if (!$noConsole) {@"
			if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
			WriteLine(message);

			string un;
			if ((string.IsNullOrEmpty(userName)) || ((options & PSCredentialUIOptions.ReadOnlyUserName) == 0))
			{
				Write("User name: ");
				un = ReadLine();
			}
			else
			{
				Write("User name: ");
				if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");
				WriteLine(userName);
				un = userName;
			}
			SecureString pwd = null;
			Write("Password: ");
			pwd = ReadLineAsSecureString();

			if (string.IsNullOrEmpty(un)) un = "<NOUSER>";
			if (!string.IsNullOrEmpty(targetName))
			{
				if (un.IndexOf('\\') < 0)
					un = targetName + "\\" + un;
			}

			PSCredential c2 = new PSCredential(un, pwd);
			return c2;
"@ } else {@"
			ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, allowedCredentialTypes, options);
			if (cred != null)
			{
				System.Security.SecureString x = new System.Security.SecureString();
				foreach (char c in cred.Password.ToCharArray())
					x.AppendChar(c);

				return new PSCredential(cred.User, x);
			}
			return new PSCredential("<NOUSER>", new System.Security.SecureString());
"@ })
		}

		public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
		{
$(if (!$noConsole) {@"
			if (!string.IsNullOrEmpty(caption)) WriteLine(caption);
			WriteLine(message);

			string un;
			if (string.IsNullOrEmpty(userName))
			{
				Write("User name: ");
				un = ReadLine();
			}
			else
			{
				Write("User name: ");
				if (!string.IsNullOrEmpty(targetName)) Write(targetName + "\\");
				WriteLine(userName);
				un = userName;
			}
			SecureString pwd = null;
			Write("Password: ");
			pwd = ReadLineAsSecureString();

			if (string.IsNullOrEmpty(un)) un = "<NOUSER>";
			if (!string.IsNullOrEmpty(targetName))
			{
				if (un.IndexOf('\\') < 0)
					un = targetName + "\\" + un;
			}

			PSCredential c2 = new PSCredential(un, pwd);
			return c2;
"@ } else {@"
			ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, PSCredentialTypes.Default, PSCredentialUIOptions.Default);
			if (cred != null)
			{
				System.Security.SecureString x = new System.Security.SecureString();
				foreach (char c in cred.Password.ToCharArray())
					x.AppendChar(c);

				return new PSCredential(cred.User, x);
			}
			return new PSCredential("<NOUSER>", new System.Security.SecureString());
"@ })
		}

		public override PSHostRawUserInterface RawUI
		{
			get
			{
				return rawUI;
			}
		}

$(if ($noConsole) {@"
		private string ibcaption;
		private string ibmessage;
"@ })

		public override string ReadLine()
		{
$(if (!$noConsole) {@"
			return Console.ReadLine();
"@ } else {@"
			string sWert = "";
			if (InputBox.Show(ibcaption, ibmessage, ref sWert) == DialogResult.OK)
				return sWert;
			else
				return "";
"@ })
		}

		private System.Security.SecureString getPassword()
		{
			System.Security.SecureString pwd = new System.Security.SecureString();
			while (true)
			{
				ConsoleKeyInfo i = Console.ReadKey(true);
				if (i.Key == ConsoleKey.Enter)
				{
					Console.WriteLine();
					break;
				}
				else if (i.Key == ConsoleKey.Backspace)
				{
					if (pwd.Length > 0)
					{
						pwd.RemoveAt(pwd.Length - 1);
						Console.Write("\b \b");
					}
				}
				else
				{
					pwd.AppendChar(i.KeyChar);
					Console.Write("*");
				}
			}
			return pwd;
		}

		public override System.Security.SecureString ReadLineAsSecureString()
		{
			System.Security.SecureString secstr = new System.Security.SecureString();
$(if (!$noConsole) {@"
			secstr = getPassword();
"@ } else {@"
			string sWert = "";

			if (InputBox.Show("", "", ref sWert, true) == DialogResult.OK)
			{
				foreach (char ch in sWert)
					secstr.AppendChar(ch);
			}
"@ })
			return secstr;
		}

		// called by Write-Host
		public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
		{
$(if (!$noConsole) {@"
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = foregroundColor;
			Console.BackgroundColor = backgroundColor;
			Console.Write(value);
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
"@ } else {@"
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);
"@ })
		}

		public override void Write(string value)
		{
$(if (!$noConsole) {@"
			Console.Write(value);
"@ } else {@"
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);
"@ })
		}

		// called by Write-Debug
		public override void WriteDebugLine(string message)
		{
$(if (!$noConsole) {@"
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = ConsoleColor.Cyan;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(string.Format("DEBUG: {0}", message));
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
"@ } else {@"
			MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Information);
"@ })
		}

		// called by Write-Error
		public override void WriteErrorLine(string value)
		{
$(if (!$noConsole) {@"
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = ConsoleColor.Red;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(string.Format("ERROR: {0}", value));
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
"@ } else {@"
			MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);
"@ })
		}

		public override void WriteLine()
		{
$(if (!$noConsole) {@"
			Console.WriteLine();
"@ } else {@"
			MessageBox.Show("", System.AppDomain.CurrentDomain.FriendlyName);
"@ })
		}

		public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
		{
$(if (!$noConsole) {@"
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = foregroundColor;
			Console.BackgroundColor = backgroundColor;
			Console.WriteLine(value);
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
"@ } else {@"
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);
"@ })
		}

		// called by Write-Output
		public override void WriteLine(string value)
		{
$(if (!$noConsole) {@"
			Console.WriteLine(value);
"@ } else {@"
			if ((!string.IsNullOrEmpty(value)) && (value != "\n"))
				MessageBox.Show(value, System.AppDomain.CurrentDomain.FriendlyName);
"@ })
		}

$(if ($noConsole) {@"
		public ProgressForm pf = null;
"@ })
		public override void WriteProgress(long sourceId, ProgressRecord record)
		{
$(if ($noConsole) {@"
			if (pf == null)
			{
				pf = new ProgressForm();
				pf.Show();
			}
			pf.Update(record);
			if (record.RecordType == ProgressRecordType.Completed)
			{
				pf = null;
			}
"@ })
		}

		// called by Write-Verbose
		public override void WriteVerboseLine(string message)
		{
$(if (!$noConsole) {@"
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = ConsoleColor.Yellow;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(string.Format("VERBOSE: {0}", message));
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
"@ } else {@"
			MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Information);
"@ })
		}

		// called by Write-Warning
		public override void WriteWarningLine(string message)
		{
$(if (!$noConsole) {@"
			ConsoleColor fgc = Console.ForegroundColor, bgc = Console.BackgroundColor;
			Console.ForegroundColor = ConsoleColor.Magenta;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(string.Format("WARNING: {0}", message));
			Console.ForegroundColor = fgc;
			Console.BackgroundColor = bgc;
"@ } else {@"
			MessageBox.Show(message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
"@ })
		}
	}

	internal class PS2EXEHost : PSHost
	{
		private PS2EXEApp parent;
		private PS2EXEHostUI ui = null;

		private CultureInfo originalCultureInfo = System.Threading.Thread.CurrentThread.CurrentCulture;

		private CultureInfo originalUICultureInfo = System.Threading.Thread.CurrentThread.CurrentUICulture;

		private Guid myId = Guid.NewGuid();

		public PS2EXEHost(PS2EXEApp app, PS2EXEHostUI ui)
		{
			this.parent = app;
			this.ui = ui;
		}

		public override System.Globalization.CultureInfo CurrentCulture
		{
			get
			{
				return this.originalCultureInfo;
			}
		}

		public override System.Globalization.CultureInfo CurrentUICulture
		{
			get
			{
				return this.originalUICultureInfo;
			}
		}

		public override Guid InstanceId
		{
			get
			{
				return this.myId;
			}
		}

		public override string Name
		{
			get
			{
				return "PS2EXE_Host";
			}
		}

		public override PSHostUserInterface UI
		{
			get
			{
				return ui;
			}
		}

		public override Version Version
		{
			get
			{
				return new Version(0, 5, 0, 6);
			}
		}

		public override void EnterNestedPrompt()
		{
		}

		public override void ExitNestedPrompt()
		{
		}

		public override void NotifyBeginApplication()
		{
			return;
		}

		public override void NotifyEndApplication()
		{
			return;
		}

		public override void SetShouldExit(int exitCode)
		{
			this.parent.ShouldExit = true;
			this.parent.ExitCode = exitCode;
		}
	}

	internal interface PS2EXEApp
	{
		bool ShouldExit { get; set; }
		int ExitCode { get; set; }
	}

	internal class PS2EXE : PS2EXEApp
	{
		public enum FileType : uint
		{
			FILE_TYPE_UNKNOWN = 0x0000,
			FILE_TYPE_DISK = 0x0001,
			FILE_TYPE_CHAR = 0x0002,
			FILE_TYPE_PIPE = 0x0003,
			FILE_TYPE_REMOTE = 0x8000
		}

		public enum STDHandle : uint
		{
			STD_INPUT_HANDLE = unchecked((uint)-10),
			STD_OUTPUT_HANDLE = unchecked((uint)-11),
			STD_ERROR_HANDLE = unchecked((uint)-12)
		}

		[DllImport("Kernel32.dll")]
		static public extern UIntPtr GetStdHandle(STDHandle stdHandle);

		[DllImport("Kernel32.dll")]
		static public extern FileType GetFileType(UIntPtr hFile);

		static public bool IsInputRedirected()
		{
			UIntPtr hInput = GetStdHandle(STDHandle.STD_INPUT_HANDLE);
			FileType fileType = (FileType)GetFileType(hInput);
			if ((fileType == FileType.FILE_TYPE_CHAR) || (fileType == FileType.FILE_TYPE_UNKNOWN))
				return false;
			return true;
		}

		private bool shouldExit;

		private int exitCode;

		public bool ShouldExit
		{
			get { return this.shouldExit; }
			set { this.shouldExit = value; }
		}

		public int ExitCode
		{
			get { return this.exitCode; }
			set { this.exitCode = value; }
		}

		[$($ApartmentType)Thread]
		private static int Main(string[] args)
		{
			PS2EXE me = new PS2EXE();

			bool paramWait = false;
			string extractFN = string.Empty;

			PS2EXEHostUI ui = new PS2EXEHostUI();
			PS2EXEHost host = new PS2EXEHost(me, ui);
			System.Threading.ManualResetEvent mre = new System.Threading.ManualResetEvent(false);

			AppDomain.CurrentDomain.UnhandledException += new UnhandledExceptionEventHandler(CurrentDomain_UnhandledException);

			try
			{
				using (Runspace myRunSpace = RunspaceFactory.CreateRunspace(host))
				{
					myRunSpace.ApartmentState = System.Threading.ApartmentState.$($ApartmentType);
					myRunSpace.Open();

					using (System.Management.Automation.PowerShell powershell = System.Management.Automation.PowerShell.Create())
					{
$(if (!$noConsole) {@"
						Console.CancelKeyPress += new ConsoleCancelEventHandler(delegate(object sender, ConsoleCancelEventArgs e)
						{
							try
							{
								powershell.BeginStop(new AsyncCallback(delegate(IAsyncResult r)
								{
									mre.Set();
									e.Cancel = true;
								}), null);
							}
							catch
							{
							};
						});
"@ })

						powershell.Runspace = myRunSpace;
						powershell.Streams.Error.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
						{
							ui.WriteErrorLine(((PSDataCollection<ErrorRecord>)sender)[e.Index].ToString());
						});

						PSDataCollection<string> colInput = new PSDataCollection<string>();

						if (IsInputRedirected())
						{ // read standard input
							string sItem = "";
							while ((sItem = Console.ReadLine()) != null)
							{ // add to powershell pipeline
								colInput.Add(sItem);
							}
						}

						colInput.Complete();

						PSDataCollection<PSObject> colOutput = new PSDataCollection<PSObject>();
						colOutput.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
						{
							ui.WriteLine(colOutput[e.Index].ToString());
						});

						int separator = 0;
						int idx = 0;
						foreach (string s in args)
						{
							if (string.Compare(s, "-wait", true) == 0)
								paramWait = true;
							else if (s.StartsWith("-extract", StringComparison.InvariantCultureIgnoreCase))
							{
								string[] s1 = s.Split(new string[] { ":" }, 2, StringSplitOptions.RemoveEmptyEntries);
								if (s1.Length != 2)
								{
$(if (!$noConsole) {@"
									Console.WriteLine("If you specify the -extract option you need to add a file for extraction in this way\r\n   -extract:\"<filename>\"");
"@ } else {@"
									MessageBox.Show("If you specify the -extract option you need to add a file for extraction in this way\r\n   -extract:\"<filename>\"", System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);
"@ })
									return 1;
								}
								extractFN = s1[1].Trim(new char[] { '\"' });
							}
							else if (string.Compare(s, "-end", true) == 0)
							{
								separator = idx + 1;
								break;
							}
							else if (string.Compare(s, "-debug", true) == 0)
							{
								System.Diagnostics.Debugger.Launch();
								break;
							}
							idx++;
						}

						string script = System.Text.Encoding.UTF8.GetString(System.Convert.FromBase64String(@"$($B64InputScript)"));

						if (!string.IsNullOrEmpty(extractFN))
						{
							System.IO.File.WriteAllText(extractFN, script);
							return 0;
						}

						powershell.AddScript(script);

						// parse parameters
						string argbuffer = null;
						// regex for named parameters
						System.Text.RegularExpressions.Regex regex = new System.Text.RegularExpressions.Regex(@"^[\/-]([^: ]+)[ :]?([^:]*)$");

						for (int i = separator; i < args.Length; i++)
						{
							System.Text.RegularExpressions.Match match = regex.Match(args[i]);
							if (match.Success && match.Groups.Count == 3)
							{ // parameter in powershell style, means named parameter found
								if (argbuffer != null) // already a named parameter in buffer, then flush it
									powershell.AddParameter(argbuffer);

								if (match.Groups[2].Value.Trim() == "")
								{ // store named parameter in buffer
									argbuffer = match.Groups[1].Value;
								}
								else
									// caution: when called in powershell $TRUE gets converted, when called in cmd.exe not
									if ((match.Groups[2].Value == "$TRUE") || (match.Groups[2].Value.ToUpper() == "\x24TRUE"))
									{ // switch found
										powershell.AddParameter(match.Groups[1].Value, true);
										argbuffer = null;
									}
									else
										// caution: when called in powershell $FALSE gets converted, when called in cmd.exe not
										if ((match.Groups[2].Value == "$FALSE") || (match.Groups[2].Value.ToUpper() == "\x24"+"FALSE"))
										{ // switch found
											powershell.AddParameter(match.Groups[1].Value, false);
											argbuffer = null;
										}
										else
										{ // named parameter with value found
											powershell.AddParameter(match.Groups[1].Value, match.Groups[2].Value);
											argbuffer = null;
										}
							}
							else
							{ // unnamed parameter found
								if (argbuffer != null)
								{ // already a named parameter in buffer, so this is the value
									powershell.AddParameter(argbuffer, args[i]);
									argbuffer = null;
								}
								else
								{ // position parameter found
									powershell.AddArgument(args[i]);
								}
							}
						}

						if (argbuffer != null) powershell.AddParameter(argbuffer); // flush parameter buffer...

						// convert output to strings
						powershell.AddCommand("out-string");
						// with a single string per line
						powershell.AddParameter("stream");

						powershell.BeginInvoke<string, PSObject>(colInput, colOutput, null, new AsyncCallback(delegate(IAsyncResult ar)
						{
							if (ar.IsCompleted)
								mre.Set();
						}), null);

						while (!me.ShouldExit && !mre.WaitOne(100))
						{ };

						powershell.Stop();
					}

					myRunSpace.Close();
				}
			}
			catch (Exception ex)
			{
$(if (!$noConsole) {@"
				Console.Write("An exception occured: ");
				Console.WriteLine(ex.Message);
"@ } else {@"
				MessageBox.Show("An exception occured: " + ex.Message, System.AppDomain.CurrentDomain.FriendlyName, MessageBoxButtons.OK, MessageBoxIcon.Error);
"@ })
			}

			if (paramWait)
			{
$(if (!$noConsole) {@"
				Console.WriteLine("Hit any key to exit...");
				Console.ReadKey();
"@ } else {@"
				MessageBox.Show("Click OK to exit...", System.AppDomain.CurrentDomain.FriendlyName);
"@ })
			}
			return me.ExitCode;
		}

		static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
		{
			throw new Exception("Unhandled exception in PS2EXE");
		}
	}
}
"@
        #endregion
        #[System.String]$programframe = $CSharpPowerShellEXEwrapper -replace '%ApartmentType%',$ApartmentType -replace '%B64InputScript%',$B64InputScript
        return $programFrame
    }
    END {}
}