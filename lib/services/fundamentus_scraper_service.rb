require "net/http"
require "nokogiri"
require "json"

class FundamentusScraperService
  CACHE_KEY = "fundamentus_scraper_html_response"
  CACHE_TTL = 1.hour

  def self.scrape(sort_column)
      # Fetch HTML with caching
      html_response = fetch_html_with_cache

      puts "\n\n>>>>>>>>> Sort column is: #{sort_column}\n"

      doc = Nokogiri::HTML(html_response)
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

        row_data = cols[0..20].map.with_index do |col, idx|
          text = col.text.strip
          # Keep the ticker (column 0) as string
          if idx == 0
            text
          else
            # Clean and convert to float for numeric columns
            cleaned = text.gsub(/[^\d.,-]/, "")
            if cleaned.match?(/[\d.,-]/)
              Float(cleaned.gsub(",", ".").gsub(/^\./, "0.")) rescue Float::NAN
            else
              Float::NAN
            end
          end
        end
        data << row_data
      end

      raise "No data rows found" unless data.any?

      df = data

      # Filter: ROIC > 10, EV/EBIT > 0 and < 15, Cotação > 1
      # Relaxed liquidity requirement since data might not be available
      filtered = df.select do |row|
        roic = row[15] # TODO: create enum for columns
        ev_ebit = row[10]
        liq_2meses = row[17]
        cotacao = row[1]

        # Check if values are valid numbers (not NaN)
        roic.is_a?(Numeric) && !roic.nan? && roic > 10 &&
        ev_ebit.is_a?(Numeric) && !ev_ebit.nan? && ev_ebit > 0 && ev_ebit < 15 &&
        cotacao.is_a?(Numeric) && !cotacao.nan? && cotacao > 1 &&
        (liq_2meses.nan? || liq_2meses > 100_000) # Relaxed liquidity or no data
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
          "P/L" => row[2],
          "ROIC" => row[15],
          "EV/EBIT" => row[10],
          "Combined_Rank" => (roic_ranks[papel] || Float::INFINITY) + (ev_ebit_ranks[papel] || Float::INFINITY)
        }
      end

      top_n = ranked.sort_by { |r| r["Combined_Rank"] }.first(500)

      {
        timestamp: Time.current.iso8601,
        stocks: top_n
      }
  end

  private

  def self.fetch_html_with_cache
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      puts "Cache miss - Fetching from fundamentus.com.br"
      fetch_html_from_fundamentus
    end
  end

  def self.fetch_html_from_fundamentus
    url = "https://fundamentus.com.br/resultado.php"
    uri = URI(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

    response = http.request(request)
    raise "Failed to fetch page: HTTP #{response.code}" unless response.code == "200"

    response.body
  end
end
