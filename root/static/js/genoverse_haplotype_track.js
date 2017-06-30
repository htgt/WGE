Genoverse.Track.View.Transcript.Haplotype = Genoverse.Track.View.Transcript.extend({
  color       : '#FF0000',
  draw        : function (features, featureContext, labelContext, scale) {
    var feature, f;
    for (var i = 0; i < features.length; i++) {
      feature = features[i];

      if (feature.position[scale].visible !== false) {

        // TODO: extend with feature.position[scale], rationalize keys
        f = $.extend({}, feature, {
          x             : feature.position[scale].X,
          y             : feature.position[scale].Y,
          width         : feature.position[scale].width,
          height        : feature.position[scale].height,
          labelPosition : feature.position[scale].label
        });

        f.color = this.track.switchStatement(f.alt, f.ref);

        this.drawFeature(f, featureContext, labelContext, scale);

        if (f.legend !== feature.legend) {
          feature.legend      = f.legend;
          feature.legendColor = f.color;
        }
      }
    }
  },
  drawFeature: function (feature, featureContext, labelContext, scale) {
    if (feature.x < 0 || feature.x + feature.width > this.width) {
      this.truncateForDrawing(feature);
    }
    if (feature.color !== false) {
      if (!feature.color) {
        this.setFeatureColor(feature);
      }
      featureContext.fillStyle = feature.color;
      featureContext.fillRect(feature.x, feature.y, feature.width, feature.height);
    }
    if (feature.clear === true) {
      featureContext.clearRect(feature.x, feature.y, feature.width, feature.height);
    }
    if (this.labels && feature.label) {
      this.drawLabel(feature, labelContext, scale);
    }
    if (feature.borderColor) {
      featureContext.strokeStyle = feature.borderColor;
      featureContext.strokeRect(feature.x, feature.y + 0.5, feature.width, feature.height);
    }
    if (feature.decorations) {
      this.decorateFeature(feature, featureContext, scale);
    }
  }
});

Genoverse.Track.Model.Haplotype = Genoverse.Track.Model.extend({

  parseData: function (data, chr, start, end) {
    var feature;

    // Example of parseData function when data is an array of hashes like { start: ..., end: ... }
    for (var i = 0; i < data.length; i++) {
      feature = data[i];

      var id      = feature.chrom + '|' + feature.pos + '|' + feature.vcf_id + '|' + feature.ref;
      var start   = parseInt(feature.pos, 10);
      var alleles = feature.alt.split(',');
      var chr     = feature.chrom;
      chr         = parseInt(chr.replace(/^[CcHhRr]{3}/, ''));

      alleles.unshift(feature.ref);

      for (var j = 0; j < alleles.length; j++) {
        var end = start + alleles[j].length - 1;

        feature.originalFeature     = data[i];
        feature.id                  = id + '|' + alleles[j];
        feature.sort                = j;
        feature.chr                 = chr;
        feature.start               = start;
        feature.end                 = end;
        feature.width               = end - start;
        feature.allele              = j === 0 ? 'REF' : 'ALT';
        feature.sequence            = alleles[j];
        feature.label               = alleles[j];
        feature.labelColor          = '#000000';

        this.insertFeature(feature);
      }
    }
  }
});