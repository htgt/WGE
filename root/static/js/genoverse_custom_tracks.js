Genoverse.Track.Crisprs = Genoverse.Track.extend({
    model     : Genoverse.Track.Model.Transcript.GFF3,
    view      : Genoverse.Track.View.Transcript.extend({
      color : '#FFFFFF'
    }),
    autoHeight : true,
    height    : 150,
    labels    : false,
    threshold : 3000,
    messages  : { threshold : 'Crisprs not displayed for regions larger than ' },

    populateMenu : function (feature) {
      var report_link = "<a href='" + this.track.crispr_report_uri + "/" + feature.name 
                                + "' target='_blank'><font color='#00FFFF'>Crispr Report</font></a>";
      var atts = {
          Start  : feature.start,
          End    : feature.end,
          Strand : feature.strand,
          Name   : feature.name,
          URL : report_link
      };
      if (feature.ot_summary){
        atts['Off-Targets'] = feature.ot_summary;
      }
      else {
        atts['Off-Targets'] = 'not computed';
      }
      return atts;
    }

});

Genoverse.Track.CrisprPairs = Genoverse.Track.extend({
    model     : Genoverse.Track.Model.Transcript.GFF3,
    view      : Genoverse.Track.View.Transcript,
    autoHeight : true,
    height    : 150,
    labels    : false,
    threshold : 3000,
    messages  : { threshold : 'Crispr pairs not displayed for regions larger than ' },

    populateMenu : function (feature) {
        var report_link = "<a href='" + this.track.pair_report_uri + "/" 
                                + feature.name 
                                + "?spacer=" + feature.spacer
                                + "' target='_blank'><font color='#00FFFF'>Crispr Pair Report</font></a>";              
        var atts = {
            Start  : feature.start,
            End    : feature.end,
            Strand : feature.strand,
            Spacer : feature.spacer,
            Name   : feature.name,
            URL    : report_link,
            'Off-Targets: Pairs' : feature.ot_summary || 'not computed',
            Left   : feature.left_ot_summary,
            Right  : feature.right_ot_summary
        };
        return atts;              
    }
});

Genoverse.Track.View.FilterCrisprs = Genoverse.Track.View.Transcript.extend({
    color : '#FFFFFF',
    drawFeature: function (feature, featureContext, labelContext, scale) {
        // Fade color of feature with off-target summary that does not match profile
        if(feature.ot_summary){
            var ot_summary = feature.ot_summary;
            // Quote keys in JSON string
            var new_ot_summary = _quoteJSONKeys(ot_summary);
            var off_targets = jQuery.parseJSON(new_ot_summary);
            var ot_profile = this.track.ot_profile;
            if( fitsOTProfile(off_targets,ot_profile) ){
                this.base.apply(this, arguments);
            }
            else{
                fadeCDS(feature.cds);
                this.base.apply(this, arguments); 
            }
        }
        else{
          // Lack of off-target summary already indicated by grey feature color
          this.base.apply(this, arguments);
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
        var ot_profile = this.track.ot_profile;
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
            fadeCDS(feature.cds);
            this.base.apply(this,arguments);
        }
        else{
            // Both match profile or 1 matches profile and 1 has no ots computed
            // or both have no ots computed
            // Lack of off-target summary already indicated by grey color
            this.base.apply(this,arguments);
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
})

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

