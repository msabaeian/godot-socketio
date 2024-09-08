class_name Request
extends HTTPRequest

signal on_response_received(response: String)
signal on_response_error(response: String)

var is_request_in_process: bool = false

func _init():
    self.request_completed.connect(_completed)
    
func request_get(url: String):
    _request(url, HTTPClient.METHOD_GET)


func request_post(url: String, body: String = ""):
    _request(url, HTTPClient.METHOD_POST, body)


func _request(url: String, method: int, body: String = ""):
    if is_request_in_process:
        return
        
    is_request_in_process = true
    request(url, [], method, body)


func clear():
    if is_request_in_process:
        cancel_request()

    is_request_in_process = false
    queue_free()


func _completed(result: HTTPRequest.Result, response_code: int, headers: PackedStringArray, body: PackedByteArray):
    is_request_in_process = false
    if result == HTTPRequest.Result.RESULT_SUCCESS:
        on_response_received.emit(body.get_string_from_utf8())
    else:
        on_response_error.emit(body.get_string_from_utf8())
        push_error("An error occurred in HTTP response, response code = %d, response body = %s" % [response_code, body.get_string_from_utf8()])
