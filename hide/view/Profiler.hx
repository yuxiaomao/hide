package hide.view;

class Profiler extends hide.ui.View<{}> {
	#if (hashlink >= "1.15.0")
	public var analyzer : hlmem.Analyzer = null;
	var hlPath = "";
	var dumpPaths : Array<String> = [];

	// Cached values
	var sumMemStats : hlmem.Result.MemStats = null;
	var sumTypeStateByCount : hlmem.Result.BlockStats = null;
	var sumTypeStateBySize : hlmem.Result.BlockStats = null;

	public function new( ?state ) {
		super(state);
		trace("new"); // TODO remove
	}

	override function onDisplay() {
		trace("onDisplay"); // TODO remove
		new Element('
		<div class="profiler">
			<div class="left-panel">
			</div>
			<div class="right-panel">
				<div class="title">Files input</div>
				<div class="files-input">
					<div class="drop-zone hidden">
						<p class="icon">+</p>
						<p class="label">Drop .hl and .dump files here</p>
					</div>
					<div class="inputs">
						<dl>
							<dt>HL file</dt><dd><input class="hl-fileselect" type="fileselect" extensions="hl"/></dd>
							<dt>Dump files</dt><dd><input class="dump-fileselect" type="fileselect" extension="dump"/></dd>
							<dt></dt><dd><input class="dump-fileselect" type="fileselect" extension="dump"/></dd>
						</dl>
						<input type="button" value="Process Files" id="process-btn"/>
					</div>
				</div>
				<div class="filters">
				</div>
			</div>
		</div>'
		).appendTo(element);

		var hlSelect = new hide.comp.FileSelect(["hl"], null, element.find(".hl-fileselect"));
		hlSelect.onChange = function() { hlPath = Ide.inst.getPath(hlSelect.path); };

		var fileSelects : Array<hide.comp.FileSelect> = [];
		for (el in element.find(".dump-fileselect")) {
			var dumpSelect = new hide.comp.FileSelect(["dump"], null, new Element(el));
			fileSelects.push(dumpSelect);

			dumpSelect.onChange = function() {
				dumpPaths = [];
				for (fs in fileSelects) {
					if (fs.path != null && fs.path != "")
						dumpPaths.push(Ide.inst.getPath(fs.path));
				}
			};
		}

		var dropZone = element.find(".drop-zone");
		dropZone.css({display:'none'});

		var inputs = element.find(".inputs");
		inputs.css({display:'block'});

		var isDragging = false;
		var wait = false;
		var fileInput = element.find(".files-input");
		fileInput.on('dragenter', function(e) {
			var dt : js.html.DataTransfer = e.originalEvent.dataTransfer;
			if (!wait && !isDragging && dt.files != null && dt.files.length > 0) {
				dropZone.css({display:'block'});
				inputs.css({display:'none'});
				dropZone.css({animation:'zoomIn .25s'});
				isDragging = true;
				wait = true;
				haxe.Timer.delay(function() wait = false, 500);
			}
		});

		fileInput.on('drop', function(e) {
			var dt : js.html.DataTransfer = e.originalEvent.dataTransfer;
			if (dt.files != null && dt.files.length > 0) {
				dropZone.css({display:'none'});
				inputs.css({display:'block'});
				isDragging = false;

				var tmpDumpPaths = [];
				for (f in dt.files) {
					var arrSplit = Reflect.getProperty(f, "name").split('.');
					var ext = arrSplit[arrSplit.length - 1];
					var p = Reflect.getProperty(f, "path");
					p = StringTools.replace(p, "\\", "/");

					if (ext == "hl") {
						hlPath = p;
						hlSelect.path = p;
						continue;
					}

					if (ext == "dump") {
						tmpDumpPaths.push(p);
						continue;
					}

					Ide.inst.error('File ${p} is not supported, please provide .dump file or .hl file');
				}

				if (tmpDumpPaths.length > 0) dumpPaths = [];
				for (idx => p in tmpDumpPaths) {
					dumpPaths.push(p);

					if (idx < fileSelects.length)
						fileSelects[idx].path = p;
				}
			}
		});

		fileInput.on('dragleave', function(e) {
			if (!wait && isDragging) {
				dropZone.css({display:'none'});
				inputs.css({display:'block'});
				isDragging = false;
				wait = true;
				haxe.Timer.delay(function() wait = false, 500);
			}
		});

		var processBtn = element.find("#process-btn");
		processBtn.on('click', function() {
			if (hlPath == null || hlPath == '' || dumpPaths == null || dumpPaths.length <= 0) {
				Ide.inst.quickMessage('.hl or/and .dump files are missing. Please provide both files before hit the process button');
				return;
			}

			clear();
			load();
			refresh();
		});
	}

	override function onBeforeClose():Bool {
		trace("onBeforeClose"); // TODO remove
		return super.onBeforeClose();
	}

	override function getTitle() {
		return "Memory profiler";
	}

	function clear() {
		trace("clear"); // TODO remove
		analyzer = null;
	}

	function load() {
		try {
			hlmem.Analyzer.useColor = false;
			analyzer = new hlmem.Analyzer();
			analyzer.loadBytecode(hlPath);
			for (i in 0...dumpPaths.length) {
				analyzer.loadMemoryDump(dumpPaths[i]);
			}
			analyzer.check();
			computeSummary();
		} catch(e) {
			Ide.inst.quickError(e);
			analyzer = null;
		}
	}

	function computeSummary() {
		var mainMemory = analyzer.getMainMemory();
		sumMemStats = mainMemory.getMemStats();
		var tmpStats = mainMemory.getBlockStatsByType();
		tmpStats.sort(true, false);
		sumTypeStateByCount = tmpStats.slice(0, 10);
		tmpStats.sort(false, false);
		sumTypeStateBySize = tmpStats.slice(0, 10);
	}

	function refresh() {
		refreshStats();
		refreshSummaryView();
	}

	function refreshStats() {
		element.find('.stats').remove();
		var statsObj = analyzer != null ? analyzer.getMemStats() : [];
		var stats = new Element ('<div class="stats"><div class="title">Stats</div></div>').appendTo(element.find('.right-panel'));
		for (idx => s in statsObj) {
			new Element('
			<h4>Memory usage</h4>
			<h5>${s.memFile}</h5>
			<div class="outer-gauge"><div class="inner-gauge" title="${hlmem.Analyzer.mb(s.used)} used (${ 100 * s.used / s.totalAllocated}% of total)" style="width:${ 100 * s.used / s.totalAllocated}%;"></div></div>
			<dl>
				<dt>Allocated</dt><dd>${hlmem.Analyzer.mb(s.totalAllocated)}</dd>
				<dt>Used</dt><dd>${hlmem.Analyzer.mb(s.used)}</dd>
				<dt>Free</dt><dd>${hlmem.Analyzer.mb(s.free)}</dd>
				<dt>GC</dt><dd>${hlmem.Analyzer.mb(s.gc)}</dd>
				<dt>&nbsp</dt><dd></dd>
				<dt>Pages</dt><dd>${s.pagesCount} (${hlmem.Analyzer.mb(s.pagesSize)})</dd>
				<dt>Roots</dt><dd>${s.rootsCount}</dd>
				<dt>Stacks</dt><dd>${s.stackCount}</dd>
				<dt>Types</dt><dd>${s.typesCount}</dd>
				<dt>Closures</dt><dd>${s.closuresCount}</dd>
				<dt>Live blocks</dt><dd>${s.blockCount}</dd>
			</dl>
			${idx < statsObj.length - 1 ? '<hr class="solid"></hr>' : ''}
			').appendTo(stats);
		}
	}

	function refreshSummaryView() {
		element.find('table').parent().remove();
		var tabCount = new ProfilerTable(this, "Type with most count", sumTypeStateByCount, 10);
		tabCount.element.appendTo(element.find(".left-panel"));
		var tabSize = new ProfilerTable(this, "Type with most size", sumTypeStateBySize, 10);
		tabSize.element.appendTo(element.find(".left-panel"));
	}

	#end

	static var _ = hide.ui.View.register(Profiler);
}

#if (hashlink >= "1.15.0")
class ProfilerTable extends hide.comp.Component {
	var profiler : Profiler;
	var title : String;
	var data : hlmem.Result.BlockStats;
	var maxLine : Int;

	public function new(profiler : Profiler, title : String, data : hlmem.Result.BlockStats, maxLine : Int) {
		super(null, null);
		this.profiler = profiler;
		this.title = title;
		this.data = data;
		this.maxLine = maxLine < data.allT.length ? maxLine : data.allT.length;
		element = new Element('
		<h4>${title}</h4>
		<div class="hide-scroll">
			<table rules=none>
				<thead>
					<td class="sort-count">Count</td>
					<td class="sort-size">Size</td>
					<td>Name</td>
				</thead>
				<tbody>
				</tbody>
			</table>
		</div>'
		);
		var body = element.find('tbody');
		if (data != null) {
			for ( i in 0...this.maxLine ) {
				var l = data.allT[i];
				var name = l.getName();
				var child = new Element('
				<tr tabindex="2">
					<td><div class="folder icon ico ico-caret-right"></div>${l.count}</td>
					<td>${hlmem.Analyzer.mb(l.size)}</td>
					<td title="${name}">${name}</td>
				</tr>'
				);
				child.appendTo(body);
			}
		}
	}
}

#end
