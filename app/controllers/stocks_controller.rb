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
    ticker = param[:stock][:ticker].strip.upcase
    result = Fundamentus::Fetcher.fetch(ticker)
    @stock = Stock.find_or_initialize_by(ticker: ticker)
    @stock.assign_attributes(
      cotacao: result[:cotacao],
      # TODO: add other infos
      fetched_at: Time.current,
      raw_html: result[:raw_html]
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

  def fetch
    @stock = Stock.find(params[:id])
    result = Fundamentus::Fetcher.fetch(@stock.ticker)
    @stock.update(
      cotacao: result[:cotacao],
      fetched_at: Time.current,
      raw_html: result[:raw_html]
    )
    redirect_to @stock, notice: "Updated."
  end
end
