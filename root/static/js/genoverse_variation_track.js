Genoverse.Track.Variation = Genoverse.Track.extend({
    // The basics for a variation track reading from Ensembl
    // Don't want the position property that comes with populateMenu by default

    // The $.get is asynchronous so we need to use a deferred object, resolve it on completion of atts
    // then Genoverse will do the right thing because populateMenu accepts a deferred object.
    //
    populateMenu: function(feature) {

        var deferred = $.Deferred();

        $.get("http://rest.ensembl.org/variation/" + ensembl_species + "/" + feature.id + "?content-type=application/json",
            write_menu);

        function write_menu(data) {
            var snp_url = "http://www.ensembl.org/" + ensembl_species + "/Variation/Explore?v=" + feature.id;
            var id_link = "<a href='" + snp_url +
                "' target='_blank'><font color='#00FFFF'>" + feature.id + "</font></a>";
            var atts = {
                type: feature.feature_type,
                ID: id_link,
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
        return (deferred);
    }
});

Genoverse.Track.MAFVariation = Genoverse.Track.extend({

    populateMenu: function(feature) {

        var snp_url = "http://www.ensembl.org/" + ensembl_species + "/Variation/Explore?v=" + feature.variation_name;
        var id_link = "<a href='" + snp_url +
            "' target='_blank'><font color='#00FFFF'>" + feature.variation_name + "</font></a>";
        var atts = {
            ID: id_link,
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
    thresholdMAF: 0.00,

    drawFeature: function(feature, featureContext, labelContext, scale) {
        if (feature.minor_allele_frequency >= this.thresholdMAF) {
            this.base.apply(this, arguments);
        }
    }
});
