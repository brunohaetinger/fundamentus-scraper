require 'httparty'
require 'nokogiri'

module Fundamentus
  class Fetcher
    BASE = "https://fundamentus.com.br/detalhes.php?papel="

    def self.fetch(ticker)
      url = BASE + CGI.escape(ticker.upcase)
      resp = HTTParty.get(url, headers: { "User-Agent" => "Chrome" })
      raise "Fetch failed: #{resp.code}" unless resp.code == 200

      doc = Nokogiri::HTML(resp.body)

      # flexible, label-based XPath: find the element that contains the label text then take the next data cell.
      get = ->(label) {
        node = doc.at_xpath("//*[normalize-space(text())='#{label}']/following::td[1]")
        node && node.text.strip.gsub('.', '').gsub(',', '.')
      }

      {
        ticker: ticker.upcase,
        cotacao: (get.call("Cotação") || get.call("Cotacao"))&.to_d,
        #TODO: add other informations
        raw_html: resp.body
      }
    end
  end
end
