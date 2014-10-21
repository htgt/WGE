Genoverse.Track.Variation = Genoverse.Track.extend({
        // The basics for a variation track reading from Ensembl
        // Don't want the position property that comes with populateMenu by default

        // The $.get is asynchronous so we need to use a deferred object, resolve it on completion of atts
        // then Genoverse will do the right thing because populateMenu accepts a deferred object.
        //
    populateMenu: function ( feature ) {
        
        var deferred = $.Deferred();

        $.get("http://rest.ensembl.org/variation/" + ensembl_species + "/" + feature.id + "?content-type=application/json",
            write_menu);

        function write_menu ( data ) {
            var atts = {
                type: feature.feature_type,
                ID:   feature.id,
                alt_alleles: feature.alt_alleles,
                ambiguity: data.ambiguity || "N/A",
                consequence: feature.consequence_type,
                MAF: data.MAF || "N/A",
                evidence: data.evidence,
                class: data.var_class,
                assembly: feature.assembly_name,
                chromosome: feature.seq_region_name,
                strand: feature.strand,
                start: feature.start,
                end: feature.end
            };        
            deferred.resolve(atts);
         }
        return( deferred );
      }
});

Genoverse.Track.MAFVariation = Genoverse.Track.extend({

    populateMenu: function ( feature ) {
        
        var atts = {
            ID: feature.variation_name,
            allele: feature.allele_string,
            SO: feature.class_SO_term,
            MAF: feature.minor_allele_frequency,
            minor_allele: feature.minor_allele,
            minor_allele_count: feature.minor_allele_count,
            source: feature.source,
            start: feature.start,
            end: feature.end,
            strand: feature.strand
        };        
        return atts;
    }
});

Genoverse.Track.View.FilterMAFVariation = Genoverse.Track.View.extend({
    thresholdMAF : 0.00,

    drawFeature: function (feature, featureContext, labelContext, scale) {
        if(feature.minor_allele_frequency >= this.thresholdMAF ){
            this.base.apply(this, arguments);
        }
    }
});

