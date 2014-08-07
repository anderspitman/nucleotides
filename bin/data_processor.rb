#!/usr/bin/env ruby

module DataProcessor

  FIELDS = {
    '# contigs (>= 1000 bp)'   => :n_contigs_gt_1000,
    'Genome fraction (%)'      => :genome_fraction,
    'NG50'                     => :ng50,
    'LG50'                     => :lg50,
    'Reference length'         => :reference_length,
    '# mismatches per 100 kbp' => :mismatches_per_100k,
    '# N\'s per 100 kbp'       => :ns_per_100k,
    '# indels per 100 kbp'     => :indels_per_100k
  }

  FORMATTERS = {
    :genome_fraction     => lambda{|i| (100 - i.to_f).round(2)},
    :mismatches_per_100k => lambda{|i| i.to_f },
    :n_contigs_gt_1000   => lambda{|i| i.to_i },
    :ng50                => lambda{|i| i.to_i },
    :lg50                => lambda{|i| i.to_i },
    :ns_per_100k         => lambda{|i| i.to_f },
    :indels_per_100k     => lambda{|i| i.to_f }
  }

  def dataset_map(file_contents)
    require 'csv'
    csv = CSV.parse(file_contents, col_sep: ",", headers: true)
    csv.map{|i| Hash[i.to_hash.map{|(k,v)| [k.to_sym,v]}]}.group_by{|i| i[:dataset]}
  end

  def parse_result(file_contents)
    require 'csv'
    csv = CSV.parse(file_contents, col_sep: "\t")
    result = csv.inject({}) do |hash, (k, v)|
      field = FIELDS[k]
      if field
        v = FORMATTERS[field].call(v) if FORMATTERS[field]
        hash[field] = v
      end
      hash
    end

    if result[:mismatches_per_100k]
      result[:incorrect] = calculate_incorrect_bases(result)
    end

    if result[:reference_length] and result[:ng50]
      result[:percent_ng50] = calculate_percent_ng50(result)
    end

    result
  end

  def calculate_incorrect_bases(v)
    values = [:indels_per_100k, :mismatches_per_100k, :ns_per_100k]
    values.map{|i| v[i] * 1000}.inject(:+) / 1000
  end

  def calculate_percent_ng50(v)
    (v[:ng50] / v[:reference_length].to_f * 100).round(2)
  end

  def metrics(dir)
    Dir["#{dir}/*/report.tsv"].inject({}) do |hash, file|
      _, _, digest, _ = file.split('/')
      result = parse_result File.read(file)
      hash[digest] = result if result[:ng50]
      hash
    end
  end

  def create_data(file_map, metrics)
    Hash[file_map.map do |data_set, config|
      values = config.select{|i| metrics.include? i[:digest] }.map do |image|
        image.merge(metrics[image[:digest]])
      end
      [data_set, values]
    end]
  end

  def execute!(directory, master_list)
    require 'yaml'
    file_map = dataset_map(File.read(master_list))
    metrics  = metrics(directory)
    puts YAML.dump(create_data(file_map, metrics))
  end

end

include DataProcessor
execute! *ARGV