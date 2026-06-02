extends Control


func _ready() -> void:
    HLog.log_level = HLog.LogLevel.INFO

    var credentials = HCredentials.new()
    credentials.product_name = ECOCredentials.PRODUCT_NAME
    credentials.product_version = ECOCredentials.PRODUCT_VERSION
    credentials.product_id = ECOCredentials.PRODUCT_ID
    credentials.sandbox_id = ECOCredentials.SANDBOX_ID
    credentials.deployment_id = ECOCredentials.DEPLOYMENT_ID
    credentials.client_id = ECOCredentials.CLIENT_ID
    credentials.client_secret = ECOCredentials.CLIENT_SECRET

    credentials.encryption_key = ECOCredentials.ENCRYPTION_KEY

    var setup_success := await HPlatform.setup_eos_async(credentials)
    if not setup_success:
        printerr("Failed to setup EOS. See logs for more details")
        return
    HPlatform.log_msg.connect(_on_eos_log_msg)
    var log_res := HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Info)
    if not EOS.is_success(log_res):
        printerr("Failed to set logging level")
        return

    HAuth.logged_in.connect(_on_logged_in)

    _devauth_login()


func _on_eos_log_msg(msg: EOS.Logging.LogMessage):
    print("SDK %s | %s" % [msg.category, msg.message])

func _on_logged_in():
    print("Logged in successfully: product_user_id=%s" % HAuth.product_user_id)
    # Example: Get top records for a leaderboard
    var records := await HLeaderboards.get_leaderboard_records_async("LEADERBOARD_ID_HERE")
    print(records)

func _devauth_login():
    var credentials = EOS.Auth.Credentials.new()
    credentials.type = EOS.Auth.LoginCredentialType.Developer
    credentials.id = "localhost:4545"
    credentials.token = "Aaron"

    var login_opts = EOS.Auth.LoginOptions.new()
    login_opts.credentials = credentials
    login_opts.scope_flags = EOS.Auth.ScopeFlags.NoFlags # | EOS.Auth.ScopeFlags.FriendsList
    EOS.Auth.AuthInterface.login(login_opts)
    IEOS.auth_interface_login_callback.connect(_on_auth_interface_login_callback)


func _on_auth_interface_login_callback(data: Dictionary):
    if not data.success:
        print("login failed")
        EOS.print_result(data)
        return
    
    print("Login successful: login_user_id=", data.local_user_id)
