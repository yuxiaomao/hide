package hrt.shgraph.nodes;

using hxsl.Ast;

@name("WorldToObject")
@description("Transform a position from world space to object space")
@group("Property")
class WorldToObject extends ShaderNodeHxsl {

	@prop() var translate : Bool = false;

	static var SRC = {
		@sginput var input : Vec3;
		@sgoutput var output : Vec3;

		@sgconst var translate : Int;

		@global var global : { @perObject var modelViewInverse : Mat4; };

		function fragment() {
			if ( translate == 1 )
				output = input * global.modelViewInverse.mat3x4();
			else
				output = input * global.modelViewInverse.mat3();
		}
	};

	override function getConstValue(name: String) : Null<Int> {
		switch (name) {
			case "translate":
				return translate ? 1 : 0;
			default:
				return null;
		}
	}

	#if editor
	override public function getPropertiesHTML(width : Float) : Array<hide.Element> {
		var elements = super.getPropertiesHTML(width);
		var container = new hide.Element('<div style="width: ${width * 0.8}px; height:40px"></div>');
		container.append('<span>&nbspTranslate</span>');
		var translateEl = new hide.Element('<input type="checkbox" id="translate"></input>');
		translateEl.prop('checked', this.translate);
		container.append(translateEl);

		translateEl.on("change", function(e) {
			this.translate = translateEl.is(':checked');
		});

		elements.push(container);
		return elements;
	}
	#end
}
