extends RefCounted

## One shared draft export across encounters. Request inputs remain job-owned.
static func save_latest(png: PackedByteArray, directory: String = "user://drawings") -> String:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return ""
	var path := directory.path_join("latest.png")
	var temporary := directory.path_join("latest-%s.tmp" % Crypto.new().generate_random_bytes(8).hex_encode())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return ""
	file.store_buffer(png)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return ""
	# Only remove the game's former timestamped exports after the new PNG is safe.
	var legacy := RegEx.new()
	legacy.compile("^E0[1-4]-(latest|preserved-[0-9]{8}-[0-9]{6}|[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9a-f]+(-[0-9]+)?)\\.png$")
	for name in DirAccess.get_files_at(directory):
		if legacy.search(name) != null:
			if DirAccess.remove_absolute(directory.path_join(name)) != OK:
				push_warning("Could not remove an older draft export.")
	return path
