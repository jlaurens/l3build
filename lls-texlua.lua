-- This is a meta file that is never included nor loaded
-- It contains luatex related declarations that are used for linting
-- with the Lua Language Server
-- The extra comments are useful in development mode
-- but should not be archived with the bundle
--
-- More declarations will appear here as soon as needed.

---@meta texlua

---@class oslib_uname
---@field sysname string
---@field machine string
---@field release string
---@field version string
---@field nodename string

---@class oslib
---@field type string "windows", "unix", and "msdos"
---@field name string "windows", "msdos", "macosx", "linux"...
---@field uname oslib_uname
---@field tmpdir fun(template: string?): string


---@class kpselib
kpse={} -- never executed, used by lls

---@class kpselib
---@field new fun(name: string, progname: string?): kpseoo
---@field set_program_name fun(name: string, progname: string?)
---@field record_input_file fun(name: string)
---@field record_output_file fun(name: string)
---@field find_file fun(filename: string, ftype_mustexist: string|boolean?, must_exist_dpi: boolean|number?): string?

---@class kpseoo
---@field set_program_name fun(self: kpseoo, name: string, progname: string?)
---@field record_input_file fun(self: kpseoo, name: string)
---@field record_output_file fun(self: kpseoo, name: string)
---@field find_file fun(self: kpseoo, filename: string, ftype_mustexist: string|boolean?, must_exist_dpi: boolean|number?): string?

---@class kpselib_lookup_table
---@field debug number? set debugging flags for this lookup
---@field format string? use specific file type (see list above)
---@field dpi number? use this resolution for this lookup; default 600
---@field path string? search in the given path
---@field all boolean? output all matches, not just the first
---@field mustexist boolean? search the disk as well as ls-R if necessary
---@field mktexpk boolean? disable/enable mktexpk generation for this lookup
---@field mktextex boolean? disable/enable mktextex generation for this lookup
---@field mktexmf boolean? disable/enable mktexmf generation for this lookup
---@field mktextfm boolean? disable/enable mktextfm generation for this lookup
---@field subdir string? only output matches whose directory part ends with the given string(s)

---@class kpselib
-- LuaTeX manual page 227 (version 118) does not mark options as optional
---@field lookup fun(filename: string, options: kpselib_lookup_table?): ...

---@class kpseoo
---@field lookup fun(self: kpseoo, filename: string, options: kpselib_lookup_table?): ...

---@class kpselib
---@field init_prog fun(prefix: string, base_dpi: number, mfmode: string, fallback: string?)
---@field readable_file fun(name: string): string?
---@field expand_path fun(s: string): string
---@field expand_var fun(s: string): string
---@field expand_braces fun(s: string): string
---@field in_name_ok fun(fname: string): boolean
---@field in_name_ok_silent_extended fun(fname: string): boolean
---@field out_name_ok fun(fname: string): boolean
---@field out_name_ok_silent_extended fun(fname: string): boolean
---@field show_path fun(ftype: string): string
---@field var_value fun(s: string): string
---@field version fun(): string
---@field check_permission fun(filename: string): number, string

---@class kpseoo
---@field init_prog fun(self: kpseoo, prefix: string, base_dpi: number, mfmode: string, fallback: string?)
---@field readable_file fun(self: kpseoo, name: string): string?
---@field expand_path fun(self: kpseoo, s: string): string
---@field expand_var fun(self: kpseoo, s: string): string
---@field expand_braces fun(self: kpseoo, s: string): string
---@field in_name_ok fun(self: kpseoo, fname: string): boolean
---@field in_name_ok_silent_extended fun(self: kpseoo, fname: string): boolean
---@field out_name_ok fun(self: kpseoo, fname: string): boolean
---@field out_name_ok_silent_extended fun(self: kpseoo, fname: string): boolean
---@field show_path fun(self: kpseoo, ftype: string): string
---@field var_value fun(self: kpseoo, s: string): string
---@field version fun(self: kpseoo): string
---@field check_permission fun(self: kpseoo, filename: string): number, string

---@class statuslib
status = {} -- never executed, used by lls

---@class statuslib
---@field luatex_version number the LuaTEX version number
---@field luatex_revision string the LuaTEX revision string
---@field banner string terminal display banner

---@class zlib
zlib = {} -- never executed, used by lls

---@class zlib
---@field compress fun(data: string, _: any, __: any, wbits: number): string
---@field crc32 fun(any?, any?): any

---@class lfslib
lfs = {} -- never executed, used by lls

---@class lfslib_attribute
---@field dev integer on Unix systems, this represents the device that the inode resides on. On Windows systems, represents the drive number of the disk containing the file
---@field ino integer on Unix systems, this represents the inode number. On Windows systems this has no meaning
---@field mode string representing the associated protection mode (the values could be file, directory, link, socket, named pipe, char device, block device or other)
---@field nlink number of hard links to the file
---@field uid integer user-id of owner (Unix only, always 0 on Windows)
---@field id integer group-id of owner (Unix only, always 0 on Windows)
---@field rdev integer on Unix systems, represents the device type, for special file inodes. On Windows systems represents the same as dev
---@field access number time of last access
---@field modification number time of last data modification
---@field change number time of last file status change
---@field size integer file size, in bytes
---@field permissions string file permissions
---@field blocks number of block allocated for file; (Unix only)
---@field blksize number optimal file system I/O blocksize; (Unix only)

---@class lfslib
---@field attributes fun(filepath: string, re: string|table): lfslib_attribute?, string? Returns a table with the file attributes corresponding to filepath (or nil followed by an error message and a system-dependent error code in case of error). If the second optional argument is given and is a string, then only the value of the named attribute is returned (this use is equivalent to lfs.attributes(filepath)[request_name], but the table is not created and only one attribute is retrieved from the O.S.). if a table is passed as the second argument, it (result_table) is filled with attributes and returned instead of a new table. The attributes are described as follows; attribute mode is a string, all the others are numbers, and the time related attributes use the same time reference of os.time:
-- This function uses stat internally thus if the given filepath is a symbolic link, it is followed (if it points to another link the chain is followed recursively) and the information is about the file it refers to. To obtain information about the link itself, see function lfs.symlinkattributes.
---@field chdir fun(path: string): true?, string? Changes the current working directory to the given path.
-- Returns true in case of success or nil plus an error string.
---@field lock_dir fun(path: string, seconds_stale: integer?): any?, string?
-- Creates a lockfile (called lockfile.lfs) in path if it does not exist and returns the lock. If the lock already exists checks if it's stale, using the second parameter (default for the second parameter is INT_MAX, which in practice means the lock will never be stale. To free the the lock call lock:free().
-- In case of any errors it returns nil and the error message. In particular, if the lock exists and is not stale it returns the "File exists" message.
---@field currentdir fun(): string?, string?
-- Returns a string with the current working directory or nil plus an error string.
---@field dir fun(path: string): fun(dir_obj: any): string?, any
-- Lua iterator over the entries of a given directory. Each time the iterator is called with dir_obj it returns a directory entry's name as a string, or nil if there are no more entries. You can also iterate by calling dir_obj:next(), and explicitly close the directory before the iteration finished with dir_obj:close(). Raises an error if path is not a directory.
---@field lock fun(filehandle: file*, mode: "r"|"w", start: integer?, end: integer?): true?, string?
-- Locks a file or a part of it. This function works on open files; the file handle should be specified as the first argument. The string mode could be either r (for a read/shared lock) or w (for a write/exclusive lock). The optional arguments start and length can be used to specify a starting point and its length; both should be numbers.
-- Returns true if the operation was successful; in case of error, it returns nil plus an error string.
---@field link fun(old: string, new: string, symlink: boolean?)
-- lfs.link (old, new[, symlink])
-- Creates a link. The first argument is the object to link to and the second is the name of the link. If the optional third argument is true, the link will by a symbolic link (by default, a hard link is created).
---@field mkdir fun(dirname: string, new: string, symlink: boolean?): status: true?, message: string?, error: integer
-- lfs.mkdir (dirname)
-- Creates a new directory. The argument is the name of the new directory.
-- Returns true in case of success or nil, an error message and a system-dependent error code in case of error.
---@field rmdir fun(dirname: string): status: true?, message: string?, error: integer
-- lfs.rmdir (dirname)
-- Removes an existing directory. The argument is the name of the directory.
-- Returns true in case of success or nil, an error message and a system-dependent error code in case of error.
---@field setmode fun(file: string, mode: string): status: true?, message: string
-- Sets the writing mode for a file. The mode string can be either "binary" or "text". Returns true followed the previous mode string for the file, or nil followed by an error string in case of errors. On non-Windows platforms, where the two modes are identical, setting the mode has no effect, and the mode is always returned as binary.
---@field symlinkattributes fun(filepath: string, mode: string): table
-- Identical to lfs.attributes except that it obtains information about the link itself (not the file it refers to). It also adds a target field, containing the file name that the symlink points to. On Windows this function does not yet support links, and is identical to lfs.attributes.
---@field touch fun(filepath : string, atime: number?, mtime: number?): status: true?, message: string?, error: integer
-- Set access and modification times of a file. This function is a bind to utime function. The first argument is the filename, the second argument (atime) is the access time, and the third argument (mtime) is the modification time. Both times are provided in seconds (which should be generated with Lua standard function os.time). If the modification time is omitted, the access time provided is used; if both times are omitted, the current time is used.
-- Returns true in case of success or nil, an error message and a system-dependent error code in case of error.
---@field unlock fun(filehandle: file*, start: integer?, length: integer?): status: true?, message: string?
-- Unlocks a file or a part of it. This function works on open files; the file handle should be specified as the first argument. The optional arguments start and length can be used to specify a starting point and its length; both should be numbers.
-- Returns true if the operation was successful; in case of error, it returns nil plus an error string.

-- Getting definitions about the unicode table is hard
-- Web sites are not easily accessible
---@class unicodelibutf8
---@field char fun(ord: integer): string

---@class unicodelib
---@field utf8 unicodelibutf8
unicode = {}  -- never executed, used by lls
