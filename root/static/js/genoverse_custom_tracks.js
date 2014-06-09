Genoverse.Track.Crisprs = Genoverse.Track.extend({
    model     : Genoverse.Track.Model.Transcript.GFF3,
    view      : Genoverse.Track.View.Transcript,
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
    drawFeature: function (feature, featureContext, labelContext, scale) {
        // only draw the feature if it has an off-target summary
        if(feature.ot_summary){
            var ot_summary = feature.ot_summary;
            // Quote keys in JSON string
            var new_ot_summary = _quoteJSONKeys(ot_summary);
            var off_targets = jQuery.parseJSON(new_ot_summary);
            var ot_profile = this.track.ot_profile;
            if( fitsOTProfile(off_targets,ot_profile) ){
                this.base.apply(this, arguments);
            }
        }
    },



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

Genoverse.Track.View.FilterCrisprPairs = Genoverse.Track.View.Transcript.extend({
    drawFeature: function (feature, featureContext, labelContext, scale) {
        // only draw the pair if its spacer is within the specified range
        if(feature.spacer <= this.track.spacer_max && feature.spacer >= this.track.spacer_min){
            this.base.apply(this, arguments);
        }
    }
})

