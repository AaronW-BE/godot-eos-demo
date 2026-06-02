extends Control


@onready var debug_text_label: RichTextLabel = $"Panel/ScrollContainer/text_debug"
@onready var epic_uid = $"VBoxContainer/MarginContainer3/VBoxContainer/HBoxContainer2/text_epic_uid"

var epic_auth_credentials = null
var current_epic_account_id = null

func _ready() -> void:
    debug_text_label.scroll_following = true
    debug_text_label.bbcode_enabled = true

    IEOS.auth_interface_login_callback.connect(_on_auth_interface_login_callback)
    IEOS.auth_interface_logout_callback.connect(_on_auth_interface_logout_callback)


func _exit_tree() -> void:
    if epic_auth_credentials:
        _loginout()

func log_msg(msg: Variant):
    debug_text_label.append_text(msg + "\n")


func log_err(msg: String):
    debug_text_label.append_text("[color=red] %s [/color] \n" % msg)

func _on_eos_log_msg(msg: EOS.Logging.LogMessage):
    log_msg("SDK %s | %s" % [msg.category, msg.message])

func _on_logged_in():
    log_msg("Logged in successfully: product_user_id=%s" % HAuth.product_user_id)
    # Example: Get top records for a leaderboard
    var records := await HLeaderboards.get_leaderboard_records_async("LEADERBOARD_ID_HERE")
    log_msg(records)

func _devauth_login():
    var credentials = EOS.Auth.Credentials.new()
    credentials.type = EOS.Auth.LoginCredentialType.Developer
    credentials.id = "localhost:4545"
    credentials.token = "Aaron"

    var login_opts = EOS.Auth.LoginOptions.new()
    login_opts.credentials = credentials
    login_opts.scope_flags = EOS.Auth.ScopeFlags.NoFlags # | EOS.Auth.ScopeFlags.FriendsList
    EOS.Auth.AuthInterface.login(login_opts)


func _loginout():
    if current_epic_account_id == null:
        log_err("Not logon")
        return

    var logout_opts = EOS.Auth.LogoutOptions.new()
    logout_opts.local_user_id = current_epic_account_id
    epic_uid.text = "Not Login"
    EOS.Auth.AuthInterface.logout(logout_opts)
    pass

func _on_auth_interface_login_callback(data: Dictionary):
    if not data.success:
        log_msg("login failed")
        EOS.print_result(data)
        return
    
    current_epic_account_id = data.local_user_id

    epic_uid.text = current_epic_account_id

    log_msg("[color=green]Login successful: %s [/color]" % data)


func _on_auth_interface_logout_callback(data: Dictionary):
    if data.result_code == EOS.Result.Success:
        log_msg("[color=green]Epic account logout success [/color]")
        # 登出成功后，清空本地保存的 ID
        current_epic_account_id = null
        
        # 这里可以触发其他的 UI 更新，比如切换回登录界面
    else:
        log_err("[color=red]Logout failed, code: %s" % data.result_code)

func _on_btn_epic_login_pressed() -> void:
    HLog.log_level = HLog.LogLevel.INFO

    if epic_auth_credentials == null:
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
            log_err("Failed to setup EOS. See logs for more details")
            return
        HPlatform.log_msg.connect(_on_eos_log_msg)
        var log_res := HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Info)
        if not EOS.is_success(log_res):
            log_err("Failed to set logging level")
            return

        epic_auth_credentials = credentials
        HAuth.logged_in.connect(_on_logged_in)

    _devauth_login()


func _on_btn_epic_logout_pressed() -> void:
    _loginout()


func _on_btn_account_login_pressed() -> void:
    var text_username: LineEdit = get_node("VBoxContainer/MarginContainer/HBoxContainer/text_username")
    var text_password: LineEdit = get_node("VBoxContainer/MarginContainer2/HBoxContainer/text_password")

    if text_username.text.is_empty() || text_password.text.is_empty():
        log_err("username or password is null")
        return

    log_msg("account login...")

    var url: String = ECOCredentials.OIDC_AUTH_TOKEN_URL
    var headers = ["Content-Type: application/x-www-form-urlencoded"]

    var client_id = ECOCredentials.OIDC_CLIENT_ID
    var body: String = "grant_type=password&client_id=%s&username=%s&password=%s" % [client_id, text_username.text, text_password.text]

    log_msg("body:  %s" % body)
    print(body)
    var http: HTTPRequest = HTTPRequest.new()
    http.request_completed.connect(_on_login_request_completed.bind(http))
    add_child(http)
    var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
    log_msg("request... %s" % error)
    if error != OK:
        log_err("Send HTTP failed, %s" % error)
        return
    log_msg("send success, wait response")

func _on_login_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
    log_msg("response")
    http_node.queue_free()
    
    if result != HTTPRequest.RESULT_SUCCESS:
        log_err("网络请求内部错误")
        return
        
    log_msg("服务器响应码: %s" % response_code)
    var response_text = body.get_string_from_utf8()
    log_msg("服务器返回内容: %s" % response_text)