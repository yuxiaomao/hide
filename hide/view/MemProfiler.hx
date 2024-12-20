package hide.view;

class MemProfiler extends hide.ui.View<{}> {
	#if (hashlink >= "1.15.0")
	public var analyzer : hlmem.Analyzer = null;
	var hlPath = "";
	var dumpPaths : Array<String> = [];

	var statsView : Element;
	var tabsView : Element;
	var summaryView : MemProfilerSummaryView;
	var inspectView : MemProfilerInspectView;

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
				<div class="info">
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
		processBtn.on('click', function(e) {
			if( hlPath == null || hlPath == '' || dumpPaths == null || dumpPaths.length <= 0 ) {
				Ide.inst.quickMessage('.hl or/and .dump files are missing. Please provide both files before hit the process button');
				return;
			}

			clear();
			load( function(b) {
				if( b )
					refresh();
			});
		});
	}

	override function onBeforeClose():Bool {
		trace("onBeforeClose"); // TODO remove
		clear();
		return super.onBeforeClose();
	}

	override function getTitle() {
		return "Memory profiler";
	}

	function showInfo( msg : String ) {
		var info = element.find(".info");
		info.html('<p>${msg}</p>');
	}

	function clear() {
		trace("clear"); // TODO remove
		analyzer = null;
		statsView = null;
		tabsView = null;
		summaryView = null;
		inspectView = null;
	}

	function load( onDone : Bool -> Void ) {
		try {
			hlmem.Analyzer.useColor = false;
			analyzer = new hlmem.Analyzer();
			analyzer.loadBytecode(hlPath);
			showInfo("Bytecode loaded, loading dump...");
			haxe.Timer.delay(() -> {
				for (i in 0...dumpPaths.length) {
					analyzer.loadMemoryDump(dumpPaths[i]);
				}
				showInfo("Memory dump loaded, building hierarchy...");
				haxe.Timer.delay(() -> {
					analyzer.check();
					showInfo("Hierarchy built.");
					haxe.Timer.delay(() -> {
						onDone(true);
					}, 0);
				}, 0);
			}, 0);
		} catch(e) {
			Ide.inst.quickError(e);
			analyzer = null;
			onDone(false);
		}
	}

	function refresh() {
		refreshStats();
		refreshTabsView();
	}

	function refreshStats() {
		if( statsView != null )
			statsView.remove();
		var statsObj = analyzer != null ? analyzer.getMemStats() : [];
		statsView = new Element('<div class="stats"><div class="title">Stats</div></div>').appendTo(element.find('.right-panel'));
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
			').appendTo(statsView);
		}
	}

	function refreshTabsView() {
		if( tabsView != null )
			tabsView.remove();
		tabsView = new Element('
		<div class="tab">
			<div class="tab-header"></div>
			<div class="tab-content"></div>
		</div>
		').appendTo(element.find(".left-panel"));
		var header = tabsView.find(".tab-header");
		var summaryBtn = new Element('<button class="tablinks">Summary</button>').appendTo(header);
		summaryBtn.on('click', (e) -> openSummaryTab());
		var inspectBtn = new Element('<button class="tablinks">Inspect</button>').appendTo(header);
		inspectBtn.on('click', (e) -> openInspectTab());
		var searchBar = new Element('<div style="display: inline"></div>').appendTo(header);
		var searchInput = new Element('<input type="text" placeholder="Search..">').appendTo(searchBar);
		var searchBtn = new Element('<button type="submit"><i class="ico ico-search"></i></button>').appendTo(searchBar);
		searchInput.keydown((e) -> if (e.key == 'Enter' || e.keyCode == 13) searchBtn.click());
		searchBtn.on('click', function(e) {
			openInspectTab(searchInput.val());
		});
		var content = tabsView.find(".tab-content");
		summaryView = new MemProfilerSummaryView(this);
		summaryView.element.appendTo(content);
		inspectView = new MemProfilerInspectView(this);
		inspectView.element.appendTo(content);
	}

	public function openSummaryTab() {
		inspectView.element.toggle(false);
		summaryView.element.toggle(true);
	}

	public function openInspectTab( ?tstr : String ) {
		summaryView.element.toggle(false);
		inspectView.element.toggle(true);
		inspectView.open(tstr);
	}

	#end

	static var _ = hide.ui.View.register(MemProfiler);
}

#if (hashlink >= "1.15.0")
class MemProfilerSummaryView extends hide.comp.Component {
	var profiler : MemProfiler;
	var sumTypeStateByCount : hlmem.Result.BlockStats = null;
	var sumTypeStateBySize : hlmem.Result.BlockStats = null;
	public function new( profiler : MemProfiler ) {
		super(null, null);
		this.profiler = profiler;
		computeSummary();
		element = new Element('<div class="hide-scroll"></div>');
		var tabCount = new MemProfilerTable(profiler, "Top 10 type on count", sumTypeStateByCount, 0);
		tabCount.element.appendTo(element);
		var tabSize = new MemProfilerTable(profiler, "Top 10 type on size", sumTypeStateBySize, 0);
		tabSize.element.appendTo(element);
	}
	function computeSummary() {
		var mainMemory = profiler.analyzer.getMainMemory();
		var tmpStats = mainMemory.getBlockStatsByType();
		tmpStats.sort(true, false);
		sumTypeStateByCount = tmpStats.slice(0, 10);
		tmpStats.sort(false, false);
		sumTypeStateBySize = tmpStats.slice(0, 10);
	}
}

class MemProfilerInspectView extends hide.comp.Component {
	var profiler : MemProfiler;
	var ttype : hlmem.TType;
	var ttypeName : String;
	var locateRootBtn : Element;
	var locateRootTable : MemProfilerTable;
	var searchBar : Element;
	var locateTable : MemProfilerTable;
	var parentsTable : MemProfilerTable;
	var subsTable : MemProfilerTable;
	public function new( profiler : MemProfiler ) {
		super(null, null);
		this.profiler = profiler;
		element = new Element('<div class="hide-scroll"></div>');
	}
	public function open( ?tstr : String ) {
		if( tstr == null || tstr.length <= 0 ) return;
		var mainMemory = profiler.analyzer.getMainMemory();
		ttype = mainMemory.resolveType(tstr);
		element.empty();
		if( ttype == null ) {
			new Element('<div><p>Cannot open type ${tstr}</p></div>').appendTo(element);
			return;
		}
		ttypeName = ttype.toString() + "#" + ttype.tid;
		var data = mainMemory.locate(ttype);
		locateTable = new MemProfilerTable(profiler, "Locate " + ttypeName, data, 10);
		locateTable.element.appendTo(element);
		var data = mainMemory.parents(ttype);
		parentsTable = new MemProfilerTable(profiler, "Parents " + ttypeName, data, 5);
		parentsTable.element.appendTo(element);
		var data = mainMemory.subs(ttype);
		subsTable = new MemProfilerTable(profiler, "Subs " + ttypeName, data, 5);
		subsTable.element.appendTo(element);
		locateRootTable = null;
		locateRootBtn = new Element('<button>Locate Root</button>').appendTo(element);
		locateRootBtn.on('click', function(e) {
			if( locateRootTable != null ) return;
			locateRootBtn.remove();
			var data = mainMemory.locate(ttype, 10);
			locateRootTable = new MemProfilerTable(profiler, "Locate 10 " + ttypeName, data, 10);
			locateRootTable.element.appendTo(element);
		});
	}
}

class MemProfilerTable extends hide.comp.Component {
	var profiler : MemProfiler;
	var title : String;
	var data : hlmem.Result.BlockStats;
	var currentLine : Int;
	var expandBtn : Element;
	public function new( profiler : MemProfiler, title : String, data : hlmem.Result.BlockStats, maxLine : Int ) {
		super(null, null);
		this.profiler = profiler;
		this.title = title;
		this.data = data;
		this.currentLine = 0;
		element = new Element('
		<div class="title">${title}</div>
		<table rules=none>
			<thead>
				<td class="sort-count">Count</td>
				<td class="sort-size">Size</td>
				<td>Name</td>
			</thead>
			<tbody>
			</tbody>
		</table>'
		);
		var size = (maxLine > 0 && maxLine < data.allT.length) ? maxLine : data.allT.length;
		expand(size);
	}

	public function expand( size : Int ) {
		if( expandBtn != null )
			expandBtn.remove();
		var delta = data.allT.length - currentLine;
		if( delta <= 0 || size <= 0 )
			return;
		if( size < delta )
			delta = size;
		var maxLine = currentLine + delta;
		var body = element.find('tbody');
		for ( i in currentLine...maxLine ) {
			var l = data.allT[i];
			var child = new MemProfilerTableLine(profiler, l);
			child.element.appendTo(body);
		}
		currentLine = maxLine;
		var delta = data.allT.length - currentLine;
		if( delta > 0 ) {
			expandBtn = new Element('<button>Expand</button>').appendTo(body);
			expandBtn.on('click', (e) -> expand(5));
		}
	}
}

class MemProfilerTableLine extends hide.comp.Component {
	var profiler : MemProfiler;
	var data : hlmem.Result.BlockStatsElement;
	public function new( profiler : MemProfiler, el : hlmem.Result.BlockStatsElement ) {
		super(null, null);
		this.profiler = profiler;
		this.data = el;
		var name = el.getName();
		element = new Element('
		<tr tabindex="2">
			<td>
				<div class="locate icon ico ico-map-marker"></div>
				${el.count}
			</td>
			<td>${hlmem.Analyzer.mb(el.size)}</td>
			<td title="${name}">${name}</td>
		</tr>'
		);
		var btn = element.find('.locate');
		btn.on('click', (e) -> locate());
	}
	public function locate() {
		profiler.openInspectTab("#" + data.tl[0]);
	}
}

#end
