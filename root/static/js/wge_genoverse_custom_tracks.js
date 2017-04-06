// WGE specific genoverse tracks
// some tracks extend tracks shared with LIMS2 so you must also use genoverse_custom_tracks.js from
// https://github.com/htgt/WebApp-Common/tree/master/shared_static/js

Genoverse.Track.View.FilterCrisprs = Genoverse.Track.View.Transcript.extend({
    color : '#FFFFFF',
    drawFeature: function (feature, featureContext, labelContext, scale) {
        // Fade color of feature with off-target summary that does not match profile
        console.log(feature);
        if(feature.ot_summary){
            var ot_summary = feature.ot_summary;
            // Quote keys in JSON string
            var new_ot_summary = _quoteJSONKeys(ot_summary);
            var off_targets = jQuery.parseJSON(new_ot_summary);
            var ot_profile = this.track.ot_profile || {};
            if( fitsOTProfile(off_targets,ot_profile) ){
                //restoreCDS(feature.cds);
                this.base.apply(this, arguments);
                if(feature.name == this.track.crispr_id){
                    highlight_feature(feature,featureContext,scale);
                }
            }
            else{
                // don't draw
                //fadeCDS(feature.cds);
                //this.base.apply(this, arguments);
            }
        }
        else{
            // Lack of off-target summary already indicated by grey feature color
            this.base.apply(this, arguments);
            if(feature.name == this.track.crispr_id){
                highlight_feature(feature,featureContext,scale);
            }
        }
    }
});

Genoverse.Track.View.FilterCrisprPairs = Genoverse.Track.View.Transcript.extend({
    color : '#FFFFFF',
    drawFeature: function (feature, featureContext, labelContext, scale) {
        // only draw the pair if its spacer is within the specified range
        var min = this.track.spacer_min;
        var max = this.track.spacer_max;
        if(min !== undefined || max !== undefined){
            if(min === undefined){ min = -10; }
            if(max === undefined){ max = 30; }
            if((feature.spacer <= max) && (feature.spacer >= min)){
                // carry on to off target check
            }
            else{
                // don't draw
                return;
            }
        }
        else{
            // skip spacer length check
        }

        // Fade color of feature with off-target summary that does not match profile
        var left_right = ['left_ot_summary','right_ot_summary'];
        var ot_profile = this.track.ot_profile || {};
        var fits_profile = left_right.map(function (summary_type){
            var summary_string = feature[summary_type];
            if(summary_string && summary_string != "not computed"){
                var summary_json = _quoteJSONKeys(summary_string);
                var off_targets = jQuery.parseJSON(summary_json);
                if( fitsOTProfile(off_targets,ot_profile) ){
                    return 1;
                }
                else{
                    return 0;
                }
            }
            else{
                // ot summary not availble
                return undefined;
            }
        });
        // If either left or right does not match ot_profile fade the colors
        if(fits_profile[0] == 0 || fits_profile[1] == 0){
            // don't draw
            //fadeCDS(feature.cds);
            //this.base.apply(this,arguments);
        }
        else{
            // Both match profile or 1 matches profile and 1 has no ots computed
            // or both have no ots computed
            // Lack of off-target summary already indicated by grey color
            //restoreCDS(feature.cds);
            this.base.apply(this,arguments);
            if(feature.name == this.track.crispr_pair_id){
                highlight_feature(feature,featureContext,scale);
            }
        }
    },

    drawIntron: function (intron, context) {
        // We have set default view color to white as we do not want lines
        // around each crispr but we need to set strokeStlye to black to
        // draw the line connecting the paired crisprs
        var orig_strokeStyle = context.strokeStyle;
        context.strokeStyle = '#000000';
        this.base.apply(this, arguments);
        context.strokeStyle = orig_strokeStyle;
    }
});

function val_in_range(val, min, max) {
  return val >= min && val <= max;
}

//method to change an amino acid after an oligo has been selected
//intended to be added to the click handler of something. needs {id: "id here"}
function change_aa(e) {
    var self = $(this);

    var idx = e.data.id - $("#oligo").data("offset");
    var codon = $("#oligo span").eq(idx);
    codon.html( self.text() );

    if ( self.hasClass("original-codon") ) {
      //clear any other selection
      self.closest("tr").find(".mutation-highlighted").removeClass("mutation-highlighted");
      codon.css({ "font-weight": "normal", "font-style": "normal" });
    }
    else {
      codon.css( { "font-weight": "bold", "font-style": "italic" });
      //strip any of our siblings of their highlighting
      self.siblings(".mutation-highlighted").removeClass("mutation-highlighted");
      self.addClass("mutation-highlighted");
    }
}

function get_protein_feature(pos) {
  var track = genoverse.tracksById['Protein'];
  //findFeatures in model doesn't work properly ?
  var features = track.model.features.search({x: pos.start, y: 0, w: (pos.end - pos.start) + 1, h: 1});

  //make sure only 1 feature has been selected
  if ( features.length > 1 ) {
    create_alert("Please select a region spanning 1 coding region only.");
    return;
  }
  else if ( features.length < 1 ) {
    create_alert("Please select a coding region");
    return;
  }

  //this could be the same as what is already in the div data but it doesn't matter
  return features[0];
}

Genoverse.Track.Controller.Protein = Genoverse.Track.Controller.Sequence.extend({
  init: function() {
    this.base();
    //set up table of silent mutations
    this.silent_mutations = silent_mutations();

    var browser = this.browser;
    var controls = browser.selectorControls;

    //add our find oligo button to the context menu
    $("<button class='oligos'>Get Oligo</button>").insertBefore( controls.find(".cancel") );

    //so we can access methods inside click method
    var parent = this;

    //the menu isn't extendable, so we have to add a new click method...
    controls.on('click', function (e) {
      if ( e.target.className != 'oligos' ) return;

      var pos = browser.getSelectorPosition();
      var len = (pos.end - pos.start) + 1;

      //see what protein feature the user has selected
      var feat = get_protein_feature(pos);
      if ( feat === undefined ) return;

      var div = $("#silent_mutations");

      //TODO:
      //add forward and reverse oligos in here
      //add transcript/protein
      if ( ! div.find("#oligo").length ) {
        //add oligo div if it isn't there already
        div.prepend("<div id='oligo_text'></div><div id='oligo'></div><div id='oligo_region'></div>");
      }

      var t = div.find("#oligo_text");
      var o = div.find("#oligo");
      var r = div.find("#oligo_region");

      div.show();

      if ( len < 10 || len > 200 ) {
        o.text("");
        r.text("");
        t.text("Oligo must be between 10 and 200 bases long");
        return;
      }

      if ( val_in_range(pos.start, feat.start, feat.end)
        || val_in_range(feat.start, pos.start, pos.end) ) {

        //if the user selection is INSIDE the exon, then expand to the nearest whole amino acid
        var start_offset = feat.start - pos.start;
        if ( start_offset < 0 ) {
          console.log("Modifying start offset");
          pos.start -= Math.abs(start_offset) % 3;
          //recompute this to be the correct bounds
          start_offset = feat.start - pos.start;
        }

        //same as above, but expanding the other end to a whole amino acid
        var end_offset = pos.end - feat.end;
        if ( end_offset < 0 ) {
          pos.end += Math.abs(end_offset) % 3;
        }

        //its inside the range we have selected, so pull up the sequence
        var seq_url = browser.tracksById['Sequence'].model.parseURL(pos.start, pos.end);
        $.get(seq_url, function(data) {
          //get the amount to cut, and if its less than 0 make it 0
          //if this is less than 0 it means the user selected bases before the exon start,
          //so we will just go from 0, the beginning of the exon
          //if they selected something larger this number will be how far into the exon
          //they chose

          var start_cut = Math.max(start_offset, 0);

          //find out how many bases of the exon are selected after start_cut
          //we do this by finding the latest start:
            //if user selection is before the start we only want exon start which is larger
            //if user selection is inside the start we only want from where they started
          //and the earliest end:
            //if user selection is past end we only want the exon end
            //if user selection is before the end we don't want any more of the exon
          var cut_length = ( Math.min(pos.end, feat.end) - Math.max(pos.start, feat.start) ) + 1;
          //force whole amino acid selection

          // console.log("feat start: " + feat.start + ", feat end: " + feat.end );
          // console.log("click start: " + pos.start + ", click end: " + pos.end);

          // console.log( "cut diff: " + (feat.start - pos.start) );
          console.log("cut start: " + start_cut + ", selected len: " + cut_length);

          var head, mid, tail;
          var head = data.substring(0, start_cut); //returns "" on 0, 0
          //substr takes x bases, whereas substring stops at point x
          var mid  = data.substr(start_cut, cut_length); //sequence we're interested in
          var tail = data.substring(start_cut+cut_length); //any stuff at the end

          var text = "Oligo for region";
          var output = "";
          if ( feat ) {
            //if the user has selected a feature we can use the strand information
            var negative_strand = false;
            if ( feat.strand == "-1" ) {
              negative_strand = true;
              text += " (negative strand)";

              //we need to reverse complement everything and swap head/tail
              //so everything is in the right order
              var tmp = tail.revcom();

              tail = head.revcom();
              mid  = mid.revcom();
              head = tmp;
            }
            else {
              text += " (positive strand)";
            }

            output += head;

            //get distance from the start of the exon to the start of the selection,
            //divide by 3 and floor to decide which row of the table the first base corresponds to
            var start_row = Math.floor( (Math.abs(start_offset)) / 3 );
            var rows = $("#silent_mutations table tbody tr");

            //switch start/end if its a negatively stranded exon
            if ( negative_strand ) {
              //invert the start/end
              start_row = (rows.length-1) - start_row;
              //we are now at the END of the bit we want,
              //so we need to now go back to the start. HOW
              start_row -= (mid.length / 3) - 1;
            }

            //store the start row so we know where to look from
            o.data("offset", start_row);

            //rows.fadeTo("slow", 0); //fade all rows
            rows.hide("slow");

            //reset spans to be as they were before
            rows.find("span").css('cursor', 'initial').unbind("click");
            for ( var i = 0; i < mid.length; i += 3 ) {
              var row = rows.eq(start_row);
              //row.stop().fadeTo("fast", 1); //unfade ones we're interested in
              row.stop().show();
              var spans = row.find("span");

              spans.each(function() {
                var self = $(this);
                //don't do anything with the blank silent mutations
                if (self.text() == "-") return true;

                //add a click listener and change the cursor
                self.click({id: start_row}, change_aa);
                spans.css('cursor', 'pointer');
              });

              //get the class of the corresponding amino acid row
              //eq gets the row at that position
              var c = row.attr("class");
              output += "<span class='"+c+"'>" + mid.substr(i, 3) + "</span>";

              //negative strand numbers need to go down as we go backwards
              //this is wrong we want to ++
              //negative_strand ? --start_row : ++start_row;
              ++start_row;
            }

            output += tail;
          }
          else {
            text += " (select an exon for silent mutations)";
            output = data;
          }

          t.html( text + ":<br>" );
          o.html( output + "<br>" + "<small>Note: oligos are expanded to the nearest whole amino acid<small>" );
          r.html("Oligo region: " + browser.chr + ":" + pos.start + "-" + pos.end);
        });
      }
      else {
        //the region is outside of our feature so do nothing
        o.text(""); //set oligo text to null
        t.text("Oligo region is outside of your selected exon.");
      }
    });


  },

  click: function(e) {
    //populate silent mutations table on first click
    if ( ! this.silent_mutations ) this.silent_mutations = silent_mutations();

    var x = e.pageX - this.container.parent().offset().left + this.browser.scaledStart;
    var y = e.pageY - $(e.target).offset().top;
    var l = e.target.className === 'labels' ? 'labelPositions' : 'featurePositions';
    var f = this[l]
            .search({ x: x, y: y, w: 1, h: 1 })
            .sort(function (a, b) { return a.sort - b.sort; })[0];

    console.log(f);

    this._create_silent_mutation_table( f );
  },

  _create_silent_mutation_table: function(f) {
    var container = $("#silent_mutations");
    container.empty(); //get rid of any previous data
    container.show(); //make sure its visible

    //keep data about what we are storing in here so we can make sure
    //the user selected area is inside
    container.data("feature", f);

    $('<h3>', {text: f.transcript + ' - ' + f.protein}).appendTo( container );

    //we add/remove the close button every time which is unnecessary
    var close = $("<div>", { "class": "close", text: "x" } )
                  .click(function(e) { container.hide(); container.empty(); container.removeData(); })
                  .appendTo( container );

    var table = $("<table>", { "class": "table" }).appendTo( container );
    table.append(
      $(
        '<thead>'                     +
        '  <th>Position</th>'         +
        '  <th>Amino Acid</th>'       +
        '  <th>Codon</th>'            +
        '  <th>Silent Mutations</th>' +
        '</thead>'
      )
    );

    var rows;

    /*
      TODO:
        add start/end base if they are present.
        will have to consider strand
    */

    for ( var i = 0; i < f.sequence.length; i++ ) {
      var aa = f.sequence[i];
      var c = f.nucleotides.substr(i*3, 3);
      //var mut = this.silent_mutations[c].join(", ") || "-";

      var mut = "";
      for ( var j = 0; j < this.silent_mutations[c].length; j++ ) {
        mut += "<span class='mutation'>" + this.silent_mutations[c][j] + "</span>";
      }

      if ( ! mut ) mut = "-"; //change empty string to -

      rows +=
        '<tr class="protein_' + aa + '">'      +
        '  <td>' + (i+f.start_index) + '</td>' +
        '  <td>' + aa                + '</td>' +
        '  <td><span class="original-codon">'  + c + '</span></td>' +
        '  <td>' + mut               + '</td>' +
        '</tr>';
    }

    table.append( "<tbody>" + rows + "</tbody>" );
  }
});

function fitsOTProfile(ot_summary, ot_profile){
        for (var mismatch_number = 0; mismatch_number < 5; mismatch_number++){
            if (mismatch_number in ot_profile){
                // Check it
                if (ot_summary[mismatch_number] <= ot_profile[mismatch_number]){
                    // It fits - continue loop to check next number of mismatches
                }
                else{
                    return false;
                }
            }
            else{
                // This mismatch number is not included in the ot_profile so we
                // assume any number of off-targets in this category is ok
            }
        }
        // If we completed the loop then the summary fits the profile
        return true;
}

function  _quoteJSONKeys(summary_string) {
      var quoted = summary_string.replace(/(\d{1}):/g,"\"$1\":");
      return quoted;
}

// Fading not used at the moment but we might want it in future
function fadeCDS(cds_array) {
    cds_array.map(function (cds){
        var color;
        if (cds.orig_color){
            color = cds.orig_color;
        }
        else{
            color = cds.color;
            cds.orig_color = color;
        }

        var new_color = colorTint(color, 0.7);
        cds.color = new_color;
    });
}

// Restores items to their original colour
function restoreCDS(cds_array){
    cds_array.map(function (cds){
        if(cds.orig_color){
            cds.color = cds.orig_color;
        }
    });
}

function colorTint(hex, factor) {
  // Adapted from ColorLuminance function by Craig Buckler at
  // http://www.sitepoint.com/javascript-generate-lighter-darker-color/

  // validate hex string
  hex = String(hex).replace(/[^0-9a-f]/gi, '');
  if (hex.length < 6) {
    hex = hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];
  }

  // convert to decimal and change luminosity
  var rgb = "#", c, i;
  for (i = 0; i < 3; i++) {
    c = parseInt(hex.substr(i*2,2), 16);
    c = Math.round(Math.min(Math.max(0, c + ( factor * (255 - c) ) ), 255)).toString(16);
    rgb += ("00"+c).substr(c.length);
  }

  return rgb;
}

function highlight_feature (feature, context, scale) {
    console.log('highlighting feature ' + feature.id);
    context.strokeStyle = 'black';
    context.lineWidth = 2;
    context.strokeRect(feature.position[scale].X, feature.position[scale].Y, feature.position[scale].width, feature.position[scale].height);
}


// function to add a bookmarking button to the crispr and crispr pair
// popup menus in the genoverse browse view
function add_bookmark_button(menu, settings){
    $.get(settings.status_uri + "/" + settings.id,
      function (data){
        console.log(data);
        if(data.error){
          console.log("Could not add bookmark button: " + data.error);
          return;
        }
        else{
          close_alerts();
          var button_text;
          if(data.is_bookmarked){
            button_text = 'Remove Bookmark';
          }
          else{
            button_text = 'Bookmark ' + settings.type;
          }

          // remove existing button (bookmark state may have changed)
          $('[name=' + settings.id + ']').remove();

          // add the new button
          menu.append('<button name="' + settings.id + '">' + button_text + '</button>');

          // add ajax request to button
          $('[name=' + settings.id + ']').click(function (event){
            toggle_bookmark(this, settings.bookmark_uri, settings.id, settings.type, settings.spinner, settings.bookmark_track);
          });
        }
      }
    );
}
