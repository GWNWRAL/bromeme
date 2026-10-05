extends OptionButton


func init(datas: Dictionary, current_selected: int = -1)->void :
	for key in datas.keys():
		add_item(datas[key], int(key))
	
	if not current_selected == -1:
		select(current_selected)
