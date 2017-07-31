//Simple PowerShell host created by Ingo Karstein (http://blog.karstein-consulting.com)
//   for PS2EXE (http://ps2exe.codeplex.com)
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
namespace ik.PowerShell
{
		internal class CredentialForm
		{
			// http://www.pinvoke.net/default.aspx/credui/CredUnPackAuthenticationBuffer.html
			// http://www.pinvoke.net/default.aspx/credui/CredUIPromptForWindowsCredentials.html
			// http://www.pinvoke.net/default.aspx/credui.creduipromptforcredentials#
			
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
				StringBuilder userPassword = new StringBuilder(), userID = new StringBuilder(user);
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
				CredUIReturnCodes returnCode = CredUIPromptForCredentials(ref credUI, target, IntPtr.Zero, 0, userID, 100, userPassword, 100, ref save, flags);

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
		internal class ReadKeyForm 
		{
			public KeyInfo key = new KeyInfo();
			public ReadKeyForm() {}
			public void ShowDialog() {}
		}
	internal class PS2EXEHostRawUI : PSHostRawUserInterface
	{
		private const bool CONSOLE = false;
		public override ConsoleColor BackgroundColor
		{
			get
			{
				return Console.BackgroundColor;
			}
			set
			{
				Console.BackgroundColor = value;
			}
		}

		public override Size BufferSize
		{
			get
			{
				if (CONSOLE)
					return new Size(Console.BufferWidth, Console.BufferHeight);
				else
					return new Size(0, 0);
			}
			set
			{
				Console.BufferWidth = value.Width;
				Console.BufferHeight = value.Height;
			}
		}
		public override Coordinates CursorPosition
		{
			get
			{
				return new Coordinates(Console.CursorLeft, Console.CursorTop);
			}
			set
			{
				Console.CursorTop = value.Y;
				Console.CursorLeft = value.X;
			}
		}
		public override int CursorSize
		{
			get
			{
				return Console.CursorSize;
			}
			set
			{
				Console.CursorSize = value;
			}
		}
		public override void FlushInputBuffer()
		{
			throw new Exception("Not implemented: ik.PowerShell.PS2EXEHostRawUI.FlushInputBuffer");
		}
		public override ConsoleColor ForegroundColor
		{
			get
			{
				return Console.ForegroundColor;
			}
			set
			{
				Console.ForegroundColor = value;
			}
		}
		public override BufferCell[,] GetBufferContents(Rectangle rectangle)
		{
			throw new Exception("Not implemented: ik.PowerShell.PS2EXEHostRawUI.GetBufferContents");
		}
		public override bool KeyAvailable
		{
			get
			{
				throw new Exception("Not implemented: ik.PowerShell.PS2EXEHostRawUI.KeyAvailable/Get");
			}
		}
		public override Size MaxPhysicalWindowSize
		{
			get { return new Size(Console.LargestWindowWidth, Console.LargestWindowHeight); }
		}
		public override Size MaxWindowSize
		{
			get { return new Size(Console.BufferWidth, Console.BufferWidth); }
		}
		public override KeyInfo ReadKey(ReadKeyOptions options)
		{
			if( CONSOLE ) {
				ConsoleKeyInfo cki = Console.ReadKey();

				ControlKeyStates cks = 0;
				if ((cki.Modifiers & ConsoleModifiers.Alt) != 0)
					cks |= ControlKeyStates.LeftAltPressed | ControlKeyStates.RightAltPressed;
				if ((cki.Modifiers & ConsoleModifiers.Control) != 0)
					cks |= ControlKeyStates.LeftCtrlPressed | ControlKeyStates.RightCtrlPressed;
				if ((cki.Modifiers & ConsoleModifiers.Shift) != 0)
					cks |= ControlKeyStates.ShiftPressed;
				if (Console.CapsLock)
					cks |= ControlKeyStates.CapsLockOn;

				return new KeyInfo((int)cki.Key, cki.KeyChar, cks, false);
			} else {
				ReadKeyForm f = new ReadKeyForm();
				f.ShowDialog();
				return f.key; 
			}
		}
		public override void ScrollBufferContents(Rectangle source, Coordinates destination, Rectangle clip, BufferCell fill)
		{
			throw new Exception("Not implemented: ik.PowerShell.PS2EXEHostRawUI.ScrollBufferContents");
		}
		public override void SetBufferContents(Rectangle rectangle, BufferCell fill)
		{
			throw new Exception("Not implemented: ik.PowerShell.PS2EXEHostRawUI.SetBufferContents(1)");
		}
		public override void SetBufferContents(Coordinates origin, BufferCell[,] contents)
		{
			throw new Exception("Not implemented: ik.PowerShell.PS2EXEHostRawUI.SetBufferContents(2)");
		}
		public override Coordinates WindowPosition
		{
			get
			{
				Coordinates s = new Coordinates();
				s.X = Console.WindowLeft;
				s.Y = Console.WindowTop;
				return s;
			}
			set
			{
				Console.WindowLeft = value.X;
				Console.WindowTop = value.Y;
			}
		}
		public override Size WindowSize
		{
			get
			{
				Size s = new Size();
				s.Height = Console.WindowHeight;
				s.Width = Console.WindowWidth;
				return s;
			}
			set
			{
				Console.WindowWidth = value.Width;
				Console.WindowHeight = value.Height;
			}
		}
		public override string WindowTitle
		{
			get
			{
				return Console.Title;
			}
			set
			{
				Console.Title = value;
			}
		}
	}
	internal class PS2EXEHostUI : PSHostUserInterface
	{
		private const bool CONSOLE = false;
		private PS2EXEHostRawUI rawUI = null;
		public PS2EXEHostUI()
			: base()
		{
			rawUI = new PS2EXEHostRawUI();
		}
		public override Dictionary<string, PSObject> Prompt(string caption, string message, System.Collections.ObjectModel.Collection<FieldDescription> descriptions)
		{
			if( !CONSOLE )
				return new Dictionary<string, PSObject>();
			if (!string.IsNullOrEmpty(caption))
				WriteLine(caption);
			if (!string.IsNullOrEmpty(message))
				WriteLine(message);
			Dictionary<string, PSObject> ret = new Dictionary<string, PSObject>();
			foreach (FieldDescription cd in descriptions)
			{
				Type t = null;
				if (string.IsNullOrEmpty(cd.ParameterAssemblyFullName))
					t = typeof(string);
				else t = Type.GetType(cd.ParameterAssemblyFullName);
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
							if (!string.IsNullOrEmpty(cd.Name))
								Write(string.Format("{0}[{1}]: ", cd.Name, index));
							data = ReadLine();

							if (string.IsNullOrEmpty(data))
								break;
							
							object o = System.Convert.ChangeType(data, elementType);

							genericListType.InvokeMember("Add", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, new object[] { o });
						}
						catch (Exception ex)
						{
							throw new Exception("Exception in ik.PowerShell.PS2EXEHostUI.Prompt*1");
						}
						index++;
					} while (true);

					System.Array retArray = (System.Array )genericListType.InvokeMember("ToArray", BindingFlags.InvokeMethod | BindingFlags.Public | BindingFlags.Instance, null, resultList, null);
					ret.Add(cd.Name, new PSObject(retArray));
				}
				else
				{

					if (!string.IsNullOrEmpty(cd.Name))
						Write(string.Format("{0}: ", cd.Name));
					object o = null;

					string l = null;
					try
					{
						l = ReadLine();

						if (string.IsNullOrEmpty(l))
							o = cd.DefaultValue;
						if (o == null)
						{
							o = System.Convert.ChangeType(l, t);
						}

						ret.Add(cd.Name, new PSObject(o));
					}
					catch
					{
						throw new Exception("Exception in ik.PowerShell.PS2EXEHostUI.Prompt*2");
					}
				}
			}
			return ret;
		}
		public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice)
		{
			if( !CONSOLE )
				return -1;
				
			if (!string.IsNullOrEmpty(caption))
				WriteLine(caption);
			WriteLine(message);
			int idx = 0;
			SortedList<string, int> res = new SortedList<string, int>();
			foreach (ChoiceDescription cd in choices)
			{
				string l = cd.Label;
				int pos = cd.Label.IndexOf('&');
				if (pos > -1)
				{
					l = cd.Label.Substring(pos + 1, 1);
				}
				res.Add(l.ToLower(), idx);

				if (idx == defaultChoice)
				{
					Console.ForegroundColor = ConsoleColor.Yellow;
					Write(ConsoleColor.Yellow, Console.BackgroundColor, string.Format("[{0}]: ", l, cd.HelpMessage));
					WriteLine(ConsoleColor.Gray, Console.BackgroundColor, string.Format("{1}", l, cd.HelpMessage));
				}
				else
				{
					Console.ForegroundColor = ConsoleColor.White;
					Write(ConsoleColor.White, Console.BackgroundColor, string.Format("[{0}]: ", l, cd.HelpMessage));
					WriteLine(ConsoleColor.Gray, Console.BackgroundColor, string.Format("{1}", l, cd.HelpMessage));
				}
				idx++;
			}
			try
			{
				string s = Console.ReadLine().ToLower();
				if (res.ContainsKey(s))
				{
					return res[s];
				}
			}
			catch { }


			return -1;
		}
		public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
		{
			if (!CONSOLE)
			{
				ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, allowedCredentialTypes, options);
				if (cred != null )
				{
					System.Security.SecureString x = new System.Security.SecureString();
					foreach (char c in cred.Password.ToCharArray())
						x.AppendChar(c);

					return new PSCredential(cred.User, x);
				}
				return null;
			}
			if (!string.IsNullOrEmpty(caption))
				WriteLine(caption);
			WriteLine(message);
			Write("User name: ");
			string un = ReadLine();
			SecureString pwd = null;
			if ((options & PSCredentialUIOptions.ReadOnlyUserName) == 0)
			{
				Write("Password: ");
				pwd = ReadLineAsSecureString();
			}
			PSCredential c2 = new PSCredential(un, pwd);
			return c2;
		}
		public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
		{
			if (!CONSOLE)
			{
				ik.PowerShell.CredentialForm.UserPwd cred = CredentialForm.PromptForPassword(caption, message, targetName, userName, PSCredentialTypes.Default, PSCredentialUIOptions.Default);
				if (cred != null )
				{
					System.Security.SecureString x = new System.Security.SecureString();
					foreach (char c in cred.Password.ToCharArray())
						x.AppendChar(c);

					return new PSCredential(cred.User, x);
				}
				return null;
			}
			if (!string.IsNullOrEmpty(caption))
				WriteLine(caption);
			WriteLine(message);
			Write("User name: ");
			string un = ReadLine();
			Write("Password: ");
			SecureString pwd = ReadLineAsSecureString();
			PSCredential c2 = new PSCredential(un, pwd);
			return c2;
		}
		public override PSHostRawUserInterface RawUI
		{
			get
			{
				return rawUI;
			}
		}
		public override string ReadLine()
		{
			return Console.ReadLine();
		}
		public override System.Security.SecureString ReadLineAsSecureString()
		{
			System.Security.SecureString x = new System.Security.SecureString();
			string l = Console.ReadLine();
			foreach (char c in l.ToCharArray())
				x.AppendChar(c);
			return x;
		}
		public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
		{
			Console.ForegroundColor = foregroundColor;
			Console.BackgroundColor = backgroundColor;
			Console.Write(value);
		}
		public override void Write(string value)
		{
			Console.ForegroundColor = ConsoleColor.White;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.Write(value);
		}
		public override void WriteDebugLine(string message)
		{
			Console.ForegroundColor = ConsoleColor.DarkMagenta;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(message);
		}
		public override void WriteErrorLine(string value)
		{
			Console.ForegroundColor = ConsoleColor.Red;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(value);
		}
		public override void WriteLine(string value)
		{
			Console.ForegroundColor = ConsoleColor.White;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(value);
		}
		public override void WriteProgress(long sourceId, ProgressRecord record)
		{

		}
		public override void WriteVerboseLine(string message)
		{
			Console.ForegroundColor = ConsoleColor.DarkCyan;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(message);
		}
		public override void WriteWarningLine(string message)
		{
			Console.ForegroundColor = ConsoleColor.Yellow;
			Console.BackgroundColor = ConsoleColor.Black;
			Console.WriteLine(message);
		}
	}
	internal class PS2EXEHost : PSHost
	{
		private const bool CONSOLE = false;
		private PS2EXEApp parent;
		private PS2EXEHostUI ui = null;
		private CultureInfo originalCultureInfo =
			System.Threading.Thread.CurrentThread.CurrentCulture;
		private CultureInfo originalUICultureInfo =
			System.Threading.Thread.CurrentThread.CurrentUICulture;
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
				return new Version(0, 2, 0, 0);
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
		private const bool CONSOLE = false;
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
		[%ApartmentType%Thread]
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
					myRunSpace.ApartmentState = System.Threading.ApartmentState.%ApartmentType%;
					myRunSpace.Open();

					using (System.Management.Automation.PowerShell powershell = System.Management.Automation.PowerShell.Create())
					{
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
						powershell.Runspace = myRunSpace;
						powershell.Streams.Progress.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
							{
								ui.WriteLine(((PSDataCollection<ProgressRecord>)sender)[e.Index].ToString());
							});
						powershell.Streams.Verbose.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
							{
								ui.WriteVerboseLine(((PSDataCollection<VerboseRecord>)sender)[e.Index].ToString());
							});
						powershell.Streams.Warning.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
							{
								ui.WriteWarningLine(((PSDataCollection<WarningRecord>)sender)[e.Index].ToString());
							});
						powershell.Streams.Error.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
							{
								ui.WriteErrorLine(((PSDataCollection<ErrorRecord>)sender)[e.Index].ToString());
							});

						PSDataCollection<PSObject> inp = new PSDataCollection<PSObject>();
						inp.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
						{
							ui.WriteLine(inp[e.Index].ToString());
						});
						PSDataCollection<PSObject> outp = new PSDataCollection<PSObject>();
						outp.DataAdded += new EventHandler<DataAddedEventArgs>(delegate(object sender, DataAddedEventArgs e)
						{
							ui.WriteLine(outp[e.Index].ToString());
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
									Console.WriteLine("If you specify the -extract option you need to add a file for extraction in this way\r\n   -extract:\"<filename>\"");
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
						string script = System.Text.Encoding.UTF8.GetString(System.Convert.FromBase64String(@"%B64InputScript%"));

						if (!string.IsNullOrEmpty(extractFN))
						{
							System.IO.File.WriteAllText(extractFN, script);
							return 0;
						}
						List<string> paramList = new List<string>(args);
						powershell.AddScript(script);
						powershell.AddParameters(paramList.GetRange(separator, paramList.Count - separator));
						powershell.AddCommand("out-string");
						powershell.AddParameter("-stream");
						powershell.BeginInvoke<PSObject, PSObject>(null, outp, null, new AsyncCallback(delegate(IAsyncResult ar)
						{
							if (ar.IsCompleted)
								mre.Set();
						}), null);

						while (!me.ShouldExit && !mre.WaitOne(100))
						{
						};
						powershell.Stop();
					}
					myRunSpace.Close();
				}
			}
			catch (Exception ex)
			{
				Console.Write("An exception occured: ");
				Console.WriteLine(ex.Message);
			}

			if (paramWait)
			{
				Console.WriteLine("Hit any key to exit...");
				Console.ReadKey();
			}
			return me.ExitCode;
		}
		static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
		{
			throw new Exception("Unhandeled exception in PS2EXE");
		}
	}
}