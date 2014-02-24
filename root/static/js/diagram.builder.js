/*
  This file is to help build diagrams like those required for the design creation page.
  It uses raphael to do all the drawing.
*/

/*
  this is basically a list used by DiagramBuilder, but each time you add a node it draws
  a line between them. it also keeps track of everything that has been added
  to the chain so more functionality could be added.
*/
function Diagram(diagramBuilder) {
  this._diagramBuilder = diagramBuilder;
  this._chain = []; 
  this._unconnectedNodes = []; //for things not on the main chain
  
  Diagram.prototype.lastElement = function() {
    return this._chain[this._chain.length - 1];
  }

  Diagram.prototype.addNode = function(node, unconnected) {
    if (unconnected) {
      //if its not connected we dont want it in the main chain.
      this._unconnectedNodes.push(node);
      return; //dont give them the node id, it cant be used.
    }

    //if you're the first element then you dont have a connection
    if (this._chain.length) {
      this._diagramBuilder._connectBoxes(this.lastElement(), node);
    }

    //return the index in case they want it.
    return this._chain.push(node);
  }

  Diagram.prototype.addUnconnectedNode = function(node) {
    this.addNode(node, 1);
  }

  Diagram.prototype.getNode = function(index) {
    return this._chain[index];
  }

  Diagram.prototype.empty = function() {
    this._chain = [];
    this._unconnectedNodes = [];
  }
}

/*
HOW TO USE:
include Raphael, jquery and qtip2 for jquery as they are all required. 

Then add this html to your page somewhere:

<div id="diagram" style="position:relative;">
  <div id="holder" style="padding-top:20px">
  </div>
</div>

then in the js add something like:

$(document).ready(function() {
  var builder = new DiagramBuilder("holder", 850, 150);

  builder.addBox("G5");
  builder.addExon();

  //etc.
});

look at how its used on create_design page for a full usage example.

An underscore before a method/attribute means, changing it will break stuff.
*/
function DiagramBuilder(id, width, height) {
  this._paper =  Raphael(id, width, height);
  this._parentDiv = $("#" + id); //this is $("#holder") in my example
  this._textFields = []; //we store any text fields we create in here for easy cleanup

  //we have this so its easy to reset. these are just global positioning type stuff
  DiagramBuilder.prototype._createAttributes = function() {
    return {
      x: 2, //this gets updated as you add elements
      y: 10,
      width: 50,
      height: 40,
      spacing: 65,
      textWidth: 50,
      textHeight: 18
    };
  };

  //never access _attributes directly (unless you are me) 
  this._attributes = this._createAttributes();
  this._chain = new Diagram(this);

  //used to automatically space elements added to the chain
  DiagramBuilder.prototype._getElementAttributes = function(width, removeSpacing) {
    //we need a copy so we can change the global one
    var attrs = this._getAttributesCopy(width, removeSpacing); 

    //if we're about to draw outside the canvas add 100px to the width
    if (attrs.x + attrs.width >= this._paper.width) {
      this._paper.setSize(this._paper.width + 100, this._paper.height);
    }

    //update the global value ready for the next element. 
    //if removeSpacing is set then dont add on more spacing or it would be added twice.
    this._attributes.x += attrs.width + ((removeSpacing) ? 0 : this._attributes.spacing);

    return attrs;
  };

  //dont use this unless you know what youre doing
  DiagramBuilder.prototype._getAttributesCopy = function(width, removeSpacing) {
    //copying objects is non trivial in js so just do this
    //allow the user to remove spacing and specify their own width if they want
    return {
      x: (removeSpacing) ? (this._attributes.x - this._attributes.spacing) : this._attributes.x, 
      y: this._attributes.y, 
      width: (width) ? width : this._attributes.width, 
      height: this._attributes.height
    };
  };

  //destroy everything
  DiagramBuilder.prototype.clearDiagram = function() {
    this._paper.clear();
    //now remove all text fields. could have just used a jquery selector
    for(var i=0; i<this._textFields.length; i++) {
      this._textFields[i].remove();
    }

    //reset all the variables
    this._textFields = [];
    this._chain.empty();
    this._attributes = this._createAttributes();
  };

  //if someone needs to do some more ADVANCED things they may need the paper instance
  DiagramBuilder.prototype.getPaper = function() {
    return this._paper;
  };

  //draw a line between any two elements (they'd better be level)
  DiagramBuilder.prototype._connectBoxes = function(first, second) {
    var first_coords = first.getBBox();
    var second_coords = second.getBBox();

    var start = first_coords.x2 + "," + ( first_coords.y + first_coords.height/2 );
    var end = second_coords.x + "," + ( second_coords.y + second_coords.height/2 );

    return this._paper.path( "M" + start + "L" + end + "z" );
  };

  DiagramBuilder.prototype._addBox = function(attrs, unconnected) {
    //draw the box
    var box = this._paper.rect(attrs.x, attrs.y, attrs.width, attrs.height).attr({
      "fill": "#356AA0", 
      "stroke-width": 1.5, 
      "fill-opacity": 0.2
    });
    var text = this._paper.text(attrs.x + (attrs.width/2), attrs.y + (attrs.height/2), attrs.text).attr({
      "font-size": 16,
      "font-weight": "bold"
    });

    //add the new element to our chain
    this._chain.addNode(box, unconnected);

    return box;
  };

  DiagramBuilder.prototype.addBox = function(text) {
    var attrs = this._getElementAttributes();
    attrs.text = text;
    return this._addBox(attrs);
  };

  DiagramBuilder.prototype.addBoxWithoutSpacing = function(text) {
    var attrs = this._getElementAttributes(null, 1); //2nd param is removeSpacing
    attrs.text = text;
    return this._addBox(attrs);
  };

  DiagramBuilder.prototype.addBoxBelowNode = function(text, node, position) {
    //position should be left or right.

    var coords = node.getBBox();
    var attrs = { 
      x: coords.x + ((position == "left") ? -coords.width/2 : coords.width/2),
      y: coords.y + coords.height,
      width: this._attributes.width,
      height: this._attributes.height,
      text: text
    };
    return this._addBox(attrs, 1);
  }

  DiagramBuilder.prototype.addExon = function() {
    var attrs = this._getElementAttributes(this._attributes.width * 1.4); //these are slightly wider
    //label all the different co-ordinates we use to (attempt to) make the code more readable.
    var coords = {
      boxLeft: attrs.x, 
      boxRight: attrs.x+attrs.width*0.7, //the actual box part only comes out 70% of the way, the remaining 30% is the point
      boxTop: attrs.y, 
      boxBottom: attrs.y+attrs.height, 
      pointX: attrs.x+attrs.width, //this is the pointed part on the side of the box
      pointY: attrs.y+attrs.height/2
    }

    //each line represents a point in the format x, y
    var points = [
      coords.boxLeft,  coords.boxTop,     //initial start
      coords.boxRight, coords.boxTop,     //top line of box
      coords.pointX,   coords.pointY,     //diagonal down to point
      coords.boxRight, coords.boxBottom,  //back in to box
      coords.boxLeft,  coords.boxBottom   //bottom line of box
    ];

    //convert the array into a path
    var path_str = "M" + points.join(",") + "z";

    //create the path object and set its attributes
    var path = this._paper.path(path_str).attr({
      "stroke-width": 1.5,
      "fill": '#3F4C6B',
    });

    //now add the EXON label, centred in the box part (ignoring the point)
    this._paper.text(attrs.x+((attrs.width*0.7)/2), attrs.y+(attrs.height/2), "Exon").attr({
      "fill": "#fff",
      "font-size": 16,
      "font-weight": "bold"
    });

    this._chain.addNode(path);

    return path; 
  };

  //critical just has the colour changed
  DiagramBuilder.prototype.addCriticalExon = function() {
    return this.addExon().attr("fill", "#CC0000");
  };

  DiagramBuilder.prototype._createArrow = function(x, y, type, to) {
    //type must be H or V
    if(! (type == "H" || type == "V") ) {
      throw("Invalid type given to _createArrow: should be H or V.");
    }
    return this._paper.path("M" + x + "," + y + type + to).attr({
      "stroke-width": 2,
      "arrow-end": "classic-wide-long"
    });
  };

  DiagramBuilder.prototype.addField = function(box, name, defaultValue, title, placement) {
    var coords = box.getBBox();

    //placement should be one of "[top|bottom|center] [left|right]"
    //the default being top center

    var textPad = 5; //used to add a little space between the element and the box

    //NOTE: these offsets are relative to the svg itself, so in the css positioning we also add some
    //additional values to line up correctly.
    var offsets = {
      "y": {
        "top": (coords.y - this._attributes.textHeight) - textPad,
        "center": coords.y + (coords.height/2 - this._attributes.textHeight/2), 
        "bottom": coords.y + coords.height + textPad
      },
      "x": {
        "left": (coords.x - this._attributes.textWidth) - textPad,
        "right": coords.x2 + textPad,
        "center": coords.x,
        "block": coords.x + ( this._attributes.textWidth / 2 )
      } 
    };

    var placement_re = /(top|bottom|center)?\s*(left|right|block)?/i;
    var match = placement_re.exec(placement || "top center"); //in case placement is null

    var yOffset, xOffset;
    if (match) {
      yOffset = offsets["y"][(match[1] == null) ? "top" : match[1]];
      xOffset = offsets["x"][(match[2] == null) ? "center" : match[2]];
    }
    else {
      throw("Invalid placement value given to addField:" + placement);
    }

    //make a new input field and position it relative to the provided box
    var field = $("<input type='text' name='" + name + "' id='" + name + "' value='" + defaultValue + "' placeholder='"+title+"' />")
      .css( {
        position: "absolute", 
        left: (xOffset - this._createAttributes().x) + "px", //offset from left of div to correct position
        top: ( yOffset + parseFloat(this._parentDiv.css("padding-top")) ) + "px", //we have padding at the top
        width: this._attributes.textWidth,
        height: this._attributes.textHeight,
        padding: 0,
        "z-index": 100
      } )
      .insertBefore( this._parentDiv );
    
    //add tooltip as a label
    field.qtip({
        content: { attr: 'placeholder' },
        position: { my: "bottomMiddle", at:"topMiddle" },
        style: { classes: 'qtip-blue' }
    });

    //we store all the text fields so we can easily delete them
    this._textFields.push(field);

    return field;
  }

  //first and second are elements you want to label between
  DiagramBuilder.prototype.addLabel = function(first, second, text, position, name, defaultValue) {
    //this will make a |<-- 5' retrieval arm length -->| or whatever label underneath two elements.
    //it will also add a text box inline with the text
    var first_coords = first.getBBox();
    var second_coords = second.getBBox();

    //what if they're not level? everything will break.
    var y_offset = 10; //how much space to leave below the elements
    var line_height = 80; //height of the label
    var text_offset = 15; //how far the text is from the line

    var coords = {};

    coords.y = first_coords.y2 + y_offset;
    coords.y2 = coords.y + line_height;
    coords.yCentre = coords.y + line_height/2;

    //done like this so the user can provide the more readable "start to end"
    var position_re = /(start|end).*(start|end)/i;
    var match = position_re.exec(position || "start to end");

    //allow the function to draw arrows at different points. default is start to end
    if (match) {
      coords.x = (match[1] == "end") ? first_coords.x2 : first_coords.x;
      coords.x2 = (match[2] == "start") ? second_coords.x : second_coords.x2;
      coords.xCentre = coords.x + Math.abs(coords.x - coords.x2)/2;
    }
    else {
      throw("Invalid position given to addLabel:" + position);
    }

    //create the path string to draw a vertical line under each element
    var left_line = "M" + coords.x + "," + coords.y  + "V" + coords.y2;
    var right_line = "M" + coords.x2 + "," + coords.y + "V" + coords.y2;

    var path = this._paper.path(left_line + right_line);

    //make a double ended arrow in the middle of the two lines we just drew
    this._createArrow(coords.xCentre, coords.yCentre, "H", coords.x);
    this._createArrow(coords.xCentre, coords.yCentre, "H", coords.x2);

    //write the text and centre it accounting for the text box
    var textF = this._paper.text(coords.xCentre-this._attributes.textWidth/2, coords.yCentre+text_offset, text).attr({"font-size": 14});

    //finally add the textbox to the center right of the label we just wrote
    var field = this.addField(textF, name, defaultValue, text, "center right");

    return path;
  };
};
