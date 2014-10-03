module BenchmarkHelpers

  def data_id(id)
    id.to_s.rjust(4, "0")
  end

  def data_description(id)
    datum = data.genomes[data_id(id).to_sym]
    raise ArgumentError, "No genome metrics found for dataset #{id}" if datum.nil?

    gc    = round_gc datum[:gc]
    size  = round_size datum[:size]

    "Microbe - approx. size: #{size}MBp, approx. GC: #{gc}%"
  end

  def datasets
    data.benchmarks.reject{|(k, _)| data.ignore.include? k}
  end

end

def round_gc(v)
  (v / 10).round * 10
end

def round_size(v)
  (v / 1000000).round
end
