require "net/http"
require "nokogiri"
require "json"

class FundamentusScraperService
  def self.scrape
      url = "https://fundamentus.com.br/resultado.php"
      headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      }

      uri = URI(url)
      response = Net::HTTP.get_response(uri, headers)
      raise "Failed to fetch page: HTTP #{response.code}" unless response.code == "200"

      doc = Nokogiri::HTML(response.body)
      table = doc.at("table#resultado")
      raise "Table not found on page" unless table
      rows = table.css("tbody tr")
      data = []
      columns = %w[
        Papel Cotação P/L P/VP PSR Div.Yield P/Ativo P/Cap.Giro P/EBIT P/Ativ\ Circ.Liq
        EV/EBIT EV/EBITDA Mrg\ Ebit Mrg.\ Líq. Liq.\ Corr. ROIC ROE Liq.2meses
        Patrim.\ Líq Dív.Brut/\ Patrim. Cresc.\ Rec.5a
      ]

      rows.each do |row|
        cols = row.css("td")
        next unless cols.length >= 21

        row_data = cols[0..20].map do |col|
          text = col.text.strip.gsub(/[^\d.,-]/, "") # Clean non-numerics
          if text.match?(/[\d.,-]/)
            Float(text.gsub(",", ".")) rescue Float::NAN
          else
            text
          end
        end
        data << row_data
      end

      raise "No data rows found" unless data.any?

      df = data

      # Filter: ROIC > 10, EV/EBIT > 0 and < 15, Liq.2meses > 1e6, Cotação > 1
      filtered = df.select do |row|
        roic = row[15] # TODO: create enum for columns
        ev_ebit = row[10]
        liq_2meses = row[17]
        cotacao = row[1]
        roic > 10 && ev_ebit > 0 && ev_ebit < 15 && liq_2meses > 1_000_000 && cotacao > 1
      end

      return { error: "No stocks match the Magic Formula criteria" } if filtered.empty?

      # Rank: ROIC descending, EV/EBIT ascending(lower EV/EBIT = higher yield)
      roic_sorted = filtered.sort_by { |row| -row[15] }
      ev_ebit_sorted = filtered.sort_by { |row| row[10] }

      roic_ranks = roic_sorted.each_with_index.with_object({}) { |(row, idx), h| h[row[0]] = idx + 1 }
      ev_ebit_ranks = ev_ebit_sorted.each_with_index.with_object({}) { |(row, idx), h| h[row[0]] = idx + 1 }

      ranked = filtered.map do |row|
        papel = row[0]
        {
          "Papel" => papel,
          "Cotação" => row[1],
          "ROIC" => row[15],
          "EV/EBIT" => row[10],
          "Combined_Rank" => (roic_ranks[papel] || Float::INFINITY) + (ev_ebit_ranks[papel] || Float::INFINITY)
        }
      end

      top_10 = ranked.sort_by { |r| r["Combined_Rank"] }.first(10)

      {
        timestamp: Time.current.isoformat,
        stocks: top_10
      }
  end
end
