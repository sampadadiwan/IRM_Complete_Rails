class AddCollatedReportToAiPortfolioReports < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_portfolio_reports, :collated_report_html, :text, limit: 16777215
  end
end
