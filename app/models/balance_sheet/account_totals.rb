class BalanceSheet::AccountTotals
  def initialize(family, sync_status_monitor:)
    @family = family
    @sync_status_monitor = sync_status_monitor
  end

  def asset_accounts
    @asset_accounts ||= account_rows.filter { |t| t.classification == "asset" }
  end

  def liability_accounts
    @liability_accounts ||= account_rows.filter { |t| t.classification == "liability" }
  end

  private
    attr_reader :family, :sync_status_monitor

    AccountRow = Data.define(:account, :converted_balance, :is_syncing) do
      def syncing? = is_syncing

      # Allows Rails path helpers to generate URLs from the wrapper
      def to_param = account.to_param
      delegate_missing_to :account
    end

    def visible_accounts
      @visible_accounts ||= family.accounts.visible.with_attached_logo
    end

    def account_rows
      @account_rows ||= query.map do |account_row|
        AccountRow.new(
          account: account_row,
          converted_balance: account_row.converted_balance,
          is_syncing: sync_status_monitor.account_syncing?(account_row)
        )
      end
    end

    def cache_key
      family.build_cache_key(
        "balance_sheet_account_rows",
        invalidate_on_data_updates: true
      )
    end

    def query
      @query ||= Rails.cache.fetch(cache_key) do
        select_converted_balance = ActiveRecord::Base.sanitize_sql_array([
          "SUM(accounts.balance * CASE WHEN accounts.currency = ? THEN 1 ELSE exchange_rates.rate END) AS converted_balance",
          family.currency
        ])

        visible_accounts
          .joins(ActiveRecord::Base.sanitize_sql_array([
            <<~SQL,
              LEFT JOIN LATERAL (
                SELECT er.rate
                FROM exchange_rates er
                WHERE er.from_currency = accounts.currency
                  AND er.to_currency = ?
                  AND er.date <= ?
                ORDER BY er.date DESC
                LIMIT 1
              ) exchange_rates ON TRUE
            SQL
            family.currency,
            Date.current
          ]))
          .select("accounts.*")
          .select(select_converted_balance)
          .group(:classification, :accountable_type, :id)
          .to_a
      end
    end
end
