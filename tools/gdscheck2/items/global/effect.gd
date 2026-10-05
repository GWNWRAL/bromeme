extends Resource

export (String) var key := ""
export (String) var text_key := ""
export (int) var value := 0
export (String) var custom_key := ""
export (int) var storage_method := 0
export (int) var effect_sign := 3
export (Array, Resource) var custom_args = []

var key_hash := 0
var custom_key_hash := 0
