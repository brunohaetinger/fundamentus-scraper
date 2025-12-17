class StocksController < ApplicationController
  def index
    @stocks = Stock.order(:ticker)
  end

  def show
    @stock = Stock.find(params[:id])
  end

  def new
    @stock = Stock.new
  end

  def create
    # ticker, cotacao, raw_html
    ticker = params[:stock][:ticker].strip.upcase
    result = Fundamentus::Fetcher.fetch(ticker)
    @stock = Stock.find_or_initialize_by(ticker: ticker)
    @stock.assign_attributes(
      price: result[:cotacao],
      pl: result[:pl],
      roe: result[:roe],
      p_vp: result[:p_vp],
      div_yield: result[:div_yield],
      fetched_at: Time.current,
      # raw_html: result[:raw_html]
    )
    if @stock.save
      redirect_to @stock, notice: "Data of #{ticker} updated."
    else
      flash.now[:alert] = @stock.errors.full_messages.to_sentence
      render :new
    end
  rescue => e
    flash.now[:alert] = "Error searching: #{e.message}"
    @stock = Stock.new(ticker: ticker)
    render :new
  end

  def magic_formula
    render layout: "application"
  end
  # stocks = Stock.where.not(pl: nil).where.not(roe: nil)
  # @stocks_with_ranks = []
  # return if stocks.empty?
  #
  # pl_ranks = {}
  # stocks.order(:pl).each_with_index do |stock, idx|
  #   pl_ranks[stock.id] = idx + 1
  # end
  #
  # roe_ranks = {}
  # stocks.order(roe: :desc).each_with_index do |stock, idx|
  #   roe_ranks[stock.id] = idx + 1
  # end
  #
  # @stocks_with_ranks = stocks.map do |stock|
  #   stock.attributes.merge(
  #     "rank_pl" => pl_ranks[stock.id],
  #     "rank_roe" => roe_ranks[stock.id],
  #     "magic" => pl_ranks[stock.id] + roe_ranks[stock.id]
  #   )
  # end
  #
  # sort_column = params[:sort] || "magic"
  # @stocks_with_ranks.sort_by! { |s| s[sort_column] || Float::INFINITY }
  def magic_formula_data
    data = FundamentusScraperService.scrape
    render json: data
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def fetch
    @stock = Stock.find(params[:id])
    result = Fundamentus::Fetcher.fetch(@stock.ticker)
    @stock.update(
      price: result[:cotacao],
      pl: result[:pl],
      roe: result[:roe],
      p_vp: result[:p_vp],
      div_yield: result[:div_yield],
      fetched_at: Time.current,
      # raw_html: result[:raw_html]
    )
    redirect_to @stock, notice: "Updated."
  end
end
