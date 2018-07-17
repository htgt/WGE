// Declare Haplotype track, extended from base track declaration.
// Any method defined here overwrites methods in Genoverse.Track for this object.
// Methods that appear in Genoverse.Track that are not defined here still can be called.
Genoverse.Track.Haplotype = Genoverse.Track.extend({
    // on click show menu, use different makeMenu function (would not overwrite correctly).
    click: function(e) {
        var target = $(e.target);
        var x = e.pageX - this.container.parent().offset().left + this.browser.scaledStart;
        var y = e.pageY - target.offset().top;

        if (this.imgContainer.hasClass('gv-flip')) {
            y = target.height() - y;
        }

        var trackId = this.track.otherTrack;
        var otherHaploTrack = window.genoverse.tracksById[trackId];
        this.track.highlightFeatures(this, otherHaploTrack.controller, x, y, target);

        return this.track.makeMenu(this.getClickedFeatures(x, y, target), e, this.track);
    },

    highlightFeatures: function(thisHaplo, otherHaploController, x, y, target) {

        if (thisHaplo.getClickedFeatures(x, y, target)[0] && otherHaploController.getClickedFeatures(x, y, target)[0]) {
            thisHaplo.getClickedFeatures(x, y, target)[0].borderColor = "#DD0000";
            otherHaploController.getClickedFeatures(x, y, target)[0].borderColor = "#DD0000";

            thisHaplo.getClickedFeatures(x, y, target)[0].pairedFeature = otherHaploController.getClickedFeatures(x, y, target)[0];


            thisHaplo.resetImages();
            thisHaplo.imgContainers.empty();
            thisHaplo.makeFirstImage();

            otherHaploController.resetImages();
            otherHaploController.imgContainers.empty();
            otherHaploController.makeFirstImage();
        }
    },
    removeFeatureHighlight: function(feature, otherFeature, thisTrack, otherTrack) {

        feature.borderColor = 0;
        otherFeature.borderColor = 0;

        thisTrack.controller.resetImages();
        thisTrack.controller.imgContainers.empty();
        thisTrack.controller.makeFirstImage();

        otherTrack.controller.resetImages();
        otherTrack.controller.imgContainers.empty();
        otherTrack.controller.makeFirstImage();
    },
    // set new menu template to remove highlight feature link.
    makeMenu: function(features, event, track) {
        this.browser.menuTemplate = this.menuTemplate;
        this.browser.makeMenu(features, event, track);
    },
    // populate menu with customised data.
    populateMenu: function(f) {
        // get updated feature.
        var feature = this.track.model.featuresById[f.id];
        // check what type of mutation feature is.
        var mutation = this.track.typeSwitch(feature.alt, feature.ref);

        // Set up hash to be used in populating the menu.
        // Hash key will appear as field name, hash value will appear as field value
        var atts = {
            Position: feature.chr + ":" + feature.pos,
            Mutation: mutation,
            Allele: feature.allele,
            Reference: feature.ref,
            // Insert HTML help ? symbol, on hover displays 'title' field.
            "Phasing Qual \
        <i class='glyphicon glyphicon-question-sign' \
        title='The quality score is a Phred-like probability of the correct phasing. Higher scores imply a lower probability of incorrect phasing.'\
        ></i>": feature.qual,
        };
        atts[this.track.line + ' 1'] = feature.haplotype_1 === 0 ? feature.ref : feature.haplotype_1;
        atts[this.track.line + ' 2'] = feature.haplotype_2 === 0 ? feature.ref : feature.haplotype_2;
        return atts;
    },
    // Set correct label info. If on wrong haplotype display ref seq as label
    setLabel: function(feature) {
        if (feature.haplotype !== this.trackNum) {
            return feature.ref;
        }
        if (feature.haplotype === this.trackNum) {
            return feature.label[0];
        }
    },
    // Return hex colour ref depending on mutation type. If !on haplotype, return grey colour.
    colourSwitch: function(feature) {

        if (feature.haplotype !== this.trackNum) {
            return "#CCCCCC";
        }

        if (feature.alt.length === 1 && feature.ref.length === 1) {
            return "#33CCFF"; //blue
        } else if (feature.alt.length > feature.ref.length) {
            return "#00AA00"; //green
        } else if (feature.alt.length < feature.ref.length) {
            return "#FFCC33"; //yellow
        }
    },
    // Return string describing mutation type based on string length difference between ref and alt sequences.
    typeSwitch: function(alt, ref) {
        if (alt.length === 1 && ref.length === 1) {
            return "Substitution";
        } else if (alt.length > ref.length) {
            return "Insertion";
        } else if (alt.length < ref.length) {
            return "Deletion";
        }
    },
    // Define new menuTemplate. Same as standard but with removed highlight this feature link.
    menuTemplate: $(
        '<div class="gv-menu">' +
        '<div class="gv-close gv-menu-button fa fa-times-circle"></div>' +
        '<div class="gv-menu-loading">Loading...</div>' +
        '<div class="gv-menu-content">' +
        '<div class="gv-title"></div>' +
        '<a class="gv-focus" href="#">Focus here</a>' +
        '<table></table>' +
        '</div>' +
        '</div>'
    ).on('click', function(e) {
        if ($(e.target).hasClass('gv-close')) {
            $(this).fadeOut('fast', function() {
                var data = $(this).data();

                var track = data.track;
                var otherTrackId = track.otherTrack;
                var otherTrack = window.genoverse.tracksById[otherTrackId];

                data.track.removeFeatureHighlight(data.feature, data.feature.pairedFeature, track, otherTrack);

                if (data.track) {
                    data.track.prop('menus', data.track.prop('menus').not(this));
                }

                data.browser.menus = data.browser.menus.not(this);
            });
        }
    })
});

// Definition for View section of track. extending Transcript view to allow for stacking of features and proper colouration.
Genoverse.Track.View.Transcript.Haplotype = Genoverse.Track.View.Transcript.extend({
    // Set default colour to bright red.
    color: '#FF0000',
    // Define Draw method to prepare features for display
    draw: function(features, featureContext, labelContext, scale) {
        var feature, f;

        for (var i = 0; i < features.length; i++) {
            feature = features[i];

            if (feature.position[scale].visible !== false) {
                var originalWidth = feature.position[scale].width;
                var adjustedWidth = feature.position[scale].width < 5 ? 5 : feature.position[scale].width;

                // TODO: extend with feature.position[scale], rationalize keys
                f = $.extend({}, feature, {
                    x: feature.position[scale].X,
                    y: feature.position[scale].Y,
                    width: adjustedWidth,
                    height: feature.position[scale].height,
                    labelPosition: feature.position[scale].label
                });

                f.haplotype = f.haplotype_1 !== 0 && f.haplotype_2 !== 0 ? // if both haplotypes do not equal 0, colour both tracks
                    this.track.trackNum : f.haplotype_1 !== 0 ? // if !both haplotypes = 0 and haplotype 1 does not equal 0, colour track 1
                    1 : f.haplotype_2 !== 0 ? // if !both haplotypes = 0 and !haplotype 1 = 0 then
                    2 : 0; // if haplotype 2 does not equal 0, colour track 2, if neither colour neither


                f.color = this.track.colourSwitch(f);
                f.filterProfile = this.track.filterProfile;

                f.label[0] = this.track.setLabel(f);

                switch (this.track.typeSwitch(f.alt, f.ref)) {
                    case "Insertion":
                        f.insertion = true;
                        f.decorations = true;
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
                    feature.legend = f.legend;
                    feature.legendColor = f.color;
                }
            }
        }
    },

    // Define drawFeature, used to actually draw and colour the feature on the scrollContainer canvas.
    drawFeature: function(feature, featureContext, labelContext, scale) {

        // Set up variables to save defaults.
        var featureX = feature.x;
        var untruncatedX = feature.untruncated === undefined ? undefined : feature.untruncated.x;

        // Set up variables for future use.
        var baseWidth = feature.width / feature.alt.length;
        var totalWidth = baseWidth < 5 ? 5 : baseWidth > 15 ? 15 : baseWidth;
        var baseX = feature.x + ((baseWidth - totalWidth) / 2);

        // If feature is not in view yet or wider than view area, truncate feature.
        if (feature.x < 0 || feature.x + feature.width > this.width) {
            this.truncateForDrawing(feature);
        }

        // If feature colour does not equal false then continue.
        if (feature.color !== false) {
            // If feature.color does not contain a value, set the value with feature.
            if (!feature.color) {
                this.setFeatureColor(feature);
            }

            feature.filter = feature.filter.split(";");

            var appliedFilters = feature.filter.filter(function(appliedFilterName) {
                return feature.filterProfile.indexOf(appliedFilterName) !== -1;
            }).filter(function(value, index, array) {
                return array.indexOf(value) === index; // removes duplicates
            });


            if (appliedFilters.length > 0) {
                feature.color = "#FFFFFF";
                feature.label = 0;
                feature.decorations = 0;
                feature.insertion = false;
            }

            // Set colour and draw rectangle for feature.
            if (feature.insertion === true) {
                // #CCCCCC - Light Grey
                // #EEEEEE - Lighter Grey
                // #AAFFAA - Light Green
                // #FFFFFF - White
                featureContext.fillStyle = feature.color === "#CCCCCC" ? "#EEEEEE" : "#AAFFAA";
            } else {
                featureContext.fillStyle = feature.color;
            }
            featureContext.fillRect(feature.x, feature.y, feature.width, feature.height);
        }

        // If feature.clear is true then remove feature from canvas.
        if (feature.clear === true) {
            featureContext.clearRect(feature.x, feature.y, feature.width, feature.height);
        }

        // If labels are enabled and feature has label then...
        if (this.labels && feature.label) {
            // Set untruncated and base x to adjusted value. (Positions this in center of feature).
            feature.untruncated === undefined ? 0 : feature.untruncated.x = baseX;
            feature.x = baseX;
            // Draw label with adjusted values.
            this.drawLabel(feature, labelContext, scale);
            // Set untruncated and base x to original values.
            feature.untruncated === undefined ? 0 : feature.untruncated.width = untruncatedX;
            feature.x = featureX;
        }
        // If feature has a border defined, draw border with borderColor
        if (feature.borderColor) {
            featureContext.strokeStyle = feature.borderColor;
            featureContext.strokeRect(feature.x, feature.y + 0.5, feature.width, feature.height);
        }
        // If feature has decorations defined, run decorateFeature method.
        // In this case it will draw a Triangle in the feature.
        if (feature.decorations) {
            this.decorateFeature(feature, featureContext, scale);
        }
    },
    // Define decorateFeature method to draw triangle in insertion feature.
    decorateFeature: function(feature, context, scale) {
        // Set up variables to position triangle within feature.
        var baseWidth = feature.width / feature.alt.length;
        var totalWidth = baseWidth < 5 ? 5 : baseWidth > 15 ? 15 : baseWidth;

        // Set triangle colour.
        context.fillStyle = feature.color;
        // Draw triangle.
        context.beginPath();
        context.moveTo(feature.x + (baseWidth / 2), feature.y);
        context.lineTo(feature.x + ((baseWidth - totalWidth) / 2), feature.y + feature.height);
        context.lineTo(feature.x + ((baseWidth + totalWidth) / 2), feature.y + feature.height);
        context.closePath();
        context.fill();
    },
});

// Definition for Model of Haplotype track.
Genoverse.Track.Model.Haplotype = Genoverse.Track.Model.extend({

    // Definition for parseData method, this is where the data from the API call is set up to the correct format.
    parseData: function(data, chr, start, end) {
        var feature;

        // For each datum in data:
        // Process and insert feature to track.
        for (var i = 0; i < data.length; i++) {
            // Set datum to feature variable.
            feature = data[i];

            // Define variables to use later.
            var id = feature.chrom + '|' + feature.pos + '|' + feature.vcf_id + '|' + feature.ref;
            var start = parseInt(feature.pos, 10);
            var alleles = feature.alt.split(',');
            var chr = feature.chrom;
            chr = parseInt(chr.replace(/^[CcHhRr]{3}/, ''));

            alleles.unshift(feature.ref);

            for (var j = 0; j < alleles.length; j++) {
                var end = start + alleles[j].length - 1;

                feature.originalFeature = data[i];
                feature.id = id + '|' + alleles[j];
                feature.sort = j;
                feature.chr = chr;
                feature.start = start;
                feature.end = end;
                feature.width = end - start;
                feature.allele = j === 0 ? 'REF' : 'ALT';
                feature.sequence = alleles[j];
                feature.label = alleles[j];
                feature.labelColor = '#000000';

                // Insert new feature to track.
                this.insertFeature(feature);
            }
        }
    }
});

Genoverse.Track.Controller.Haplotype = Genoverse.Track.Controller.extend({

    addDomElements: function() {
        this.base.apply(this, arguments);

        this.container.attr("id", "haplo_" + this.track.trackNum);
    },

    render: function(features, img) {
        var params = img.data();
        features = this.view.positionFeatures(this.view.scaleFeatures(features, params.scale), params); // positionFeatures alters params.featureHeight, so this must happen before the canvases are created
        var featureCanvas = $('<canvas>').attr({
            width: params.width,
            height: params.featureHeight || 1
        });
        var labelCanvas = this.prop('labels') === 'separate' && params.labelHeight ? featureCanvas.clone().attr('height', params.labelHeight) : featureCanvas;
        var featureContext = featureCanvas[0].getContext('2d');
        var labelContext = labelCanvas[0].getContext('2d');

        featureContext.font = labelContext.font = this.prop('font');

        switch (this.prop('labels')) {
            case false:
                break;
            case 'overlay':
                labelContext.textAlign = 'center';
                labelContext.textBaseline = 'middle';
                break;
            default:
                labelContext.textAlign = 'left';
                labelContext.textBaseline = 'top';
                break;
        }

        this.view.draw(features, featureContext, labelContext, params.scale);

        img.attr('src', featureCanvas[0].toDataURL());

        if (labelContext !== featureContext) {
            img.clone(true).attr({
                'class': 'gv-labels',
                src: labelCanvas[0].toDataURL()
            }).insertAfter(img);
        }

        this.checkHeight();

        featureCanvas = labelCanvas = img = null;
    }

});
