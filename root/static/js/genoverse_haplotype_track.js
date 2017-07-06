Genoverse.Track.View.Transcript.Haplotype = Genoverse.Track.View.Transcript.extend({
  color       : '#FF0000',
  positionFeatures: function (features, params) {
    params.margin = this.prop('margin');

    for (var i = 0; i < features.length; i++) {
      for (var j = 0; j < params.scale.length; j++) {
        console.log(params.scale);
        features[i].position[params.scale[j]].width = features[i].position[params.scale[j]].width < 5 ? 5 : features[i].position[params.scale[j]].width;
      }
      this.positionFeature(features[i], params);
    }

    params.width         = Math.ceil(params.width);
    params.height        = Math.ceil(params.height);
    params.featureHeight = Math.max(Math.ceil(params.featureHeight), this.prop('resizable') ? Math.max(this.prop('height'), this.prop('minLabelHeight')) : 0);
    params.labelHeight   = Math.ceil(params.labelHeight);

    return features;
  },
  draw        : function (features, featureContext, labelContext, scale) {
    var feature, f;
    //this.track.d3Scale.domain([0, scale]);

    for (var i = 0; i < features.length; i++) {
      feature = features[i];

      if (feature.position[scale].visible !== false) {
        var originalWidth = feature.position[scale].width;
        var adjustedWidth = feature.position[scale].width < 5 ? 5 : feature.position[scale].width;

        // TODO: extend with feature.position[scale], rationalize keys
        f = $.extend({}, feature, {
          x             : feature.position[scale].X,
          y             : feature.position[scale].Y,
          width         : adjustedWidth,
          height        : feature.position[scale].height,
          labelPosition : feature.position[scale].label
        });

        //##############################################
        // SET DRAWING PARAMS HERE, X AND Y AND WIDTH AND HEIGHT
        //##############################################




        f.color = this.track.colourSwitch(f.alt, f.ref);

        switch(this.track.typeSwitch(f.alt, f.ref)) {
          case "Insertion":
            f.insertion  = true;
            break;
          case "Deletion":
            f.deletion = true;
            break;
          case "Substitution":
            f.substitution = true;
            break;
        }

        this.drawFeature(f, featureContext, labelContext, scale);

        if (f.legend !== feature.legend) {
          feature.legend      = f.legend;
          feature.legendColor = f.color;
        }
      }
    }
  },
  drawFeature: function (feature, featureContext, labelContext, scale) {

    var featureX = feature.x;

    var baseWidth = feature.width / feature.alt.length;
    var totalWidth = baseWidth < 5 ? 5 : baseWidth > 15 ? 15 : baseWidth;
    var baseX     = feature.x + ((baseWidth - totalWidth) / 2) ;
    if (feature.x < 0 || feature.x + feature.width > this.width) {
      this.truncateForDrawing(feature);
    }
    var untruncatedX = feature.untruncated === undefined ? undefined : feature.untruncated.x;
    if (feature.color !== false) {
      if (!feature.color) {
        this.setFeatureColor(feature);
      }

      if (feature.substitution === true) {
        featureContext.fillStyle = "#E1E1FF";
        featureContext.fillRect(feature.x, feature.y, feature.width, feature.height);

        featureContext.fillStyle = feature.color;
        var cx    = feature.x + (baseWidth / 2),        // circle x coordinate
            cy    = feature.y + (feature.height / 2),   // circle y coordinate
            cr    = totalWidth / 2,                     // circle radius
            csa   = 0,                                  // circle start angle
            cea   = Math.PI * 2,                        // circle end angle
            ccw   = true;                               // circle clockwise
        featureContext.arc(cx, cy, cr, csa, cea, ccw);
        featureContext.closePath();
        featureContext.fill();



      } else if (feature.insertion === true) {
        console.log(feature);
        featureContext.fillStyle = "#E1FFE1";
        featureContext.fillRect(feature.x, feature.y, feature.width, feature.height);

        featureContext.fillStyle = feature.color;
        featureContext.beginPath();
        featureContext.moveTo(feature.x + (baseWidth / 2), feature.y);
        featureContext.lineTo(feature.x + ((baseWidth - totalWidth) / 2), feature.y + feature.height);
        featureContext.lineTo(feature.x + ((baseWidth + totalWidth) / 2), feature.y + feature.height);
        featureContext.closePath();
        featureContext.fill();

      } else if (feature.deletion === true) {
        featureContext.fillStyle = feature.color;

        featureContext.fillRect(feature.x, feature.y, feature.width, feature.height);
      }

    }
    if (feature.clear === true) {
      featureContext.clearRect(feature.x, feature.y, feature.width, feature.height);
    }
    if (this.labels && feature.label) {
      feature.untruncated === undefined ? 0 : feature.untruncated.x = baseX;
      feature.x = baseX;
      this.drawLabel(feature, labelContext, scale);
      feature.untruncated === undefined ? 0 : feature.untruncated.width = untruncatedX;
      feature.x = featureX;
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

Genoverse.Track.Controller.Haplotype = Genoverse.Track.Controller.extend({

  render: function (features, img) {
    var params         = img.data();
        features       = this.view.positionFeatures(this.view.scaleFeatures(features, params.scale), params); // positionFeatures alters params.featureHeight, so this must happen before the canvases are created
    var featureCanvas  = $('<canvas>').attr({ width: params.width, height: params.featureHeight || 1 });
    var labelCanvas    = this.prop('labels') === 'separate' && params.labelHeight ? featureCanvas.clone().attr('height', params.labelHeight) : featureCanvas;
    var featureContext = featureCanvas[0].getContext('2d');
    var labelContext   = labelCanvas[0].getContext('2d');

    featureContext.font = labelContext.font = this.prop('font');

    switch (this.prop('labels')) {
      case false     : break;
      case 'overlay' : labelContext.textAlign = 'center'; labelContext.textBaseline = 'middle'; break;
      default        : labelContext.textAlign = 'left';   labelContext.textBaseline = 'top';    break;
    }

    this.view.draw(features, featureContext, labelContext, params.scale);

    img.attr('src', featureCanvas[0].toDataURL());

    if (labelContext !== featureContext) {
      img.clone(true).attr({ 'class': 'gv-labels', src: labelCanvas[0].toDataURL() }).insertAfter(img);
    }

    this.checkHeight();

    featureCanvas = labelCanvas = img = null;
  },

});