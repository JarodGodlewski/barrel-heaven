extends Node

const PATH := "user://qa_errors.log"

var _mu := Mutex.new()
var _logger: Logger
var count := 0


class Sink extends Logger:
	var host: Node

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _traces: Array) -> void:
		if host == null:
			return
		var kind := "SCRIPT" if error_type == Logger.ERROR_TYPE_SCRIPT else "ERROR"
		if error_type == Logger.ERROR_TYPE_WARNING:
			kind = "WARN"
		var msg := rationale if rationale != "" else code
		host.call_deferred("_append", kind, file, line, function, msg)

	func _log_message(message: String, error: bool) -> void:
		if error and host != null:
			host.call_deferred("_append", "STDERR", "", 0, "", message.strip_edges())


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_line("# qa %s" % Time.get_datetime_string_from_system())
		f.close()
	_logger = Sink.new()
	(_logger as Sink).host = self
	OS.add_logger(_logger)


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)


func _append(kind: String, file: String, line: int, function: String, msg: String) -> void:
	_mu.lock()
	count += 1
	var row := "%s\t%s\t%s:%d\t%s\t%s" % [Time.get_datetime_string_from_system(), kind, file, line, function, msg]
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	else:
		f.seek_end()
	if f:
		f.store_line(row)
		f.close()
	_mu.unlock()
