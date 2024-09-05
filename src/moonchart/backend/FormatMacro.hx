package moonchart.backend;

import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;
import sys.FileSystem;

using haxe.macro.Tools;
using haxe.macro.PositionTools;
using StringTools;

/**
 *	@author Ne_Eo
 */
class FormatMacro
{
	public static function hex(n:UInt, ?digits:Int)
	{
		var s = "";
		var hexChars = "0123456789abcdef";
		do
		{
			s = hexChars.charAt(n & 15) + s;
			n >>>= 4;
		}
		while (n > 0);

		if (digits != null)
			while (s.length < digits)
				s = "0" + s;

		return s;
	}

	public static function crc32(str:String):String
	{
		var crc = new haxe.crypto.Crc32();
		crc.update(haxe.io.Bytes.ofString(str), 0, str.length);
		return hex(crc.get(), 8);
	}

	public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();

		var found = false;
		for (field in fields)
		{
			if (field.name == "__getFormat")
			{
				var file = getPathFromLib(getFileFromPos(field.pos));
				var funcName = "__moonchart_format_" + crc32(file);
				// trace(file, funcName);
				field.name = funcName;
				found = true;
				break;
			}
		}
		if (!found)
		{
			var clRef = Context.getLocalClass();
			if (clRef == null)
				return fields;
			var cl = clRef.get();
			var pos = cl.pos;
			var file = getPathFromLib(getFileFromPos(pos));

			// only error if the class is the same name as the filename
			if (file == cl.pack.concat([cl.name]).join("."))
			{
				Context.error("Couldn't find __getFormat function", pos);
			}
		}
		return fields;
	}

	static function getDirFromPos(pos:Position):String
	{
		var posInfo = pos.getInfos();
		var file = Path.directory(posInfo.file);

		if (!Path.isAbsolute(file))
		{
			file = Path.join([Sys.getCwd(), file]);
		}
		return Path.normalize(file);
	}

	static function getFileFromPos(pos:Position):String
	{
		var posInfo = pos.getInfos();
		var file = posInfo.file;

		if (!Path.isAbsolute(Path.directory(posInfo.file)))
		{
			file = Path.join([Sys.getCwd(), file]);
		}
		return Path.normalize(file);
	}

	static function getPathFromLib(file:String):String
	{
		file = Path.normalize(file).replace("\\", "/");

		file = Path.withoutExtension(file);
		file = file.replace("/", ".");

		var idx = file.lastIndexOf("moonchart.");
		if (idx == -1)
			return file;
		return file.substr(idx);
	}

	macro public static function loadFormats()
	{
		var pos = Context.currentPos();

		var sourcePath = getDirFromPos(pos); // moonchart/backend/
		var split = sourcePath.replace("\\", "/").split("/");
		split.pop(); // moonchart/
		split.push("formats"); // moonchart/formats/
		sourcePath = split.join("/");

		// trace(sourcePath);

		function getAllFiles(path:String):Array<String>
		{
			var files:Array<String> = [];

			function collectFiles(currentPath:String)
			{
				for (file in FileSystem.readDirectory(currentPath))
				{
					var p = '$currentPath/$file';
					if (FileSystem.isDirectory(p))
					{
						collectFiles(p);
					}
					else
					{
						files.push(p);
					}
				}
			}
			collectFiles(path);
			return files;
		}

		var files = getAllFiles(sourcePath);

		for (i => file in files)
		{
			files[i] = getPathFromLib(file);
		}

		files = files.filter((file) ->
		{
			return file != "moonchart.formats.BasicFormat";
		});

		// trace(files);

		var block = [macro var formats:Array<moonchart.backend.FormatData> = []];

		for (file in files)
		{
			var funcName = "__moonchart_format_" + crc32(file);
			block.push(macro formats.push($p{file.split(".")}.$funcName()));
		}
		block.push(macro formats);

		// trace((macro $b{block}).toString());

		return macro $b{block};
	}
}

/*class FormatMacro {
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();

		var clRef = Context.getLocalClass();
		if (clRef == null)
			return fields;
		var cl = clRef.get();

		var setupData:Expr = null;
		var metaEntry = null;
		var meta = cl.meta.get();
		for(m in meta) {
			if (m.name == ":setupMacro") {
				setupData = m.params[0];
				metaEntry = m;
			}
		}
		if(metaEntry != null) {
			meta.remove(metaEntry);
		}

		if(setupData == null) {
			// Context.error("Couldn't find :setupMacro meta", Context.currentPos());
			return fields;
		}

		//trace(setupData.toString());

		var formatDetector = TypeTools.getClass(Context.getType("moonchart.backend.FormatDetector"));

		var existing:Array<Expr> = [];
		for(meta in formatDetector.meta.get()) {
			if(meta.name == "formats") {
				existing = meta.params;
			}
		}
		existing.push(setupData);
		formatDetector.meta.add("formats", existing, formatDetector.pos);

		return fields;
	}
}*/