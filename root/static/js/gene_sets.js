Genoverse.Track.Model.Gene.GeneSet = Genoverse.Track.Model.Gene.extend({
    dataRequestLimit: 1e7,
    parseData: function(data, chr) {
        for (var i = 0; i < data.length; i++) {
            var feature = data[i];
            if (feature.feature_type_id === 'gene' && !this.featuresById[feature.id]) {
                feature.chr   = feature.chr_name || chr;
                feature.start = feature.chr_start;
                feature.end   = feature.chr_end;
                feature.label = parseInt(feature.strand, 10) === 1 ? (feature.name || feature.id) + ' >' : '< ' + (feature.name || feature.id);
                feature.transcripts = [];
                this.insertFeature(feature);
            }
        }
    },
});

function getGeneSetLabel(feature) {
    var id = feature.id.match(/^([a-z]+)(\d+)$/i)[2] || feature.id;
    return parseInt(feature.strand, 10) === 1 ?
        feature.gene.name + '-' + id + ' >' :
        '< ' + feature.gene.name + '-' + id;
}

Genoverse.Track.Model.Transcript.GeneSet = Genoverse.Track.Model.Transcript.extend({
    dataRequestLimit: 1e7,
    findOrAddParent: function(feature) {
        if (this.featuresById[feature.parent_id]) {
            return this.featuresById[feature.parent_id];
        }
        var gene = this.genes[feature.parent_id];
        if (!gene) {
            return 0;
        }
        gene.gene  = gene;
        gene.label = getGeneSetLabel(gene);
        gene.exons = {};
        gene.cds   = {};
        this.insertFeature(gene);
        return gene;
    },
    // The url above responds in json format, data is an array
    // We assume that parents always preceed children in data array, gene -> transcript -> exon
    parseData: function(data, chr) {
        if (!('genes' in this)) {
            this.genes = {};
        }
        for (var i = 0; i < data.length; i++) {
            var feature = data[i];

            feature.chr   = feature.chr_name || chr;
            feature.start = feature.chr_start;
            feature.end   = feature.chr_end;
            if (feature.feature_type_id === 'gene' && !this.genes[feature.id]) {
                this.genes[feature.id] = feature;
            }
            else if (feature.feature_type_id === 'rna' && !this.featuresById[feature.id]) {
                feature.gene  = this.genes[feature.parent_id];
                feature.label = getGeneSetLabel(feature);
                feature.exons = {};
                feature.cds   = {};
                this.insertFeature(feature);
            }
            else if (feature.feature_type_id === 'exon') {
                var p = this.findOrAddParent(feature);
                if (p) {
                    p.exons[feature.id] = feature;
                }
            }
            else if (feature.feature_type_id === 'CDS') {
                var p = this.findOrAddParent(feature);
                if (p) {
                    p.cds[feature.id] = feature;
                }
            }
        }
    }
});

Genoverse.Track.View.GeneSet = Genoverse.Track.View.Transcript.extend({
    setFeatureColor: function(feature) {
        feature.color = '#000000';
        var colors = {
            'protein_coding': {
                color: '#a00000', //dark red
                legend: 'Protein coding'
            },
            'psueogene': {
                color: '#666666', //medium grey
                legend: 'Pseudogene'
            },
            'mRNA': {
                color: '#808000', //dark yellow
                legend: 'mRNA'
            },
            'miRNA': {
                color: '#00a000', //dark green
                legend: 'miRNA'
            },
            'transcript': {
                color: '#0000f0', //blue
                legend: 'Transcript'
            },
            'primary_transcript': {
                color: '#0000a0', //dark blue
                legend: 'Primary transcript'
            },
        };

        if (feature.biotype in colors) {
            feature.color = colors[feature.biotype].color;
            feature.legend = colors[feature.biotype].legend;
        } else if (/rna$/i.test(feature.biotype)) {
            feature.color = '#8b668b'; //plum
            feature.legend = 'RNA gene';
        }

        feature.labelColor = feature.color;
    }
});

Genoverse.Track.GeneSet = Genoverse.Track.extend({
    id: 'geneset',
    name: 'GeneSet',
    height: 200,
    legend: true,

    constructor: function() {
        this.base.apply(this, arguments);
        if (this.legend === true) {
            this.addLegend();
        }
    },

    populateMenu: function(feature) {
        var menu = {
            title: getGeneSetLabel(feature),
            Id: feature.id,
            Location: feature.chr_name + ':' + feature.chr_start + '-' + feature.chr_end,
            Biotype: feature.biotype,
            Strand: feature.strand,
        };
        ['name', 'gene_id', 'transcript_id', 'protein_id', 'description', 'rank']
        .forEach(function(prop, i) {
            if (feature[prop]) {
                menu[prop] = feature[prop];
            }
        });
        return menu;
    },
    100000: {
        model: Genoverse.Track.Model.Gene.GeneSet,
    },
    1: {
        model: Genoverse.Track.Model.Transcript.GeneSet,
    },
    view: Genoverse.Track.View.GeneSet,
});
