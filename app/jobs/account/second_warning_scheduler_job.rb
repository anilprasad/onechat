class Account::SecondWarningSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    config_name = 'INITIAL_WARNING_AFTER_DAYS'
    no_days = GlobalConfig.get(config_name)[config_name] || 30
    no_days = no_days.to_i
    intemediatry_config_name = 'INTEMEDIATRY_WARNING'
    intemediatry_days = GlobalConfig.get(intemediatry_config_name)[intemediatry_config_name] || 4
    total_no_days = intemediatry_days.to_i + no_days

    Account.where(deletion_email_reminder: :initial_reminder).each do |account|
      subscription = account.account_billing_subscriptions.where(cancelled_at: nil)&.last

      next unless subscription.blank? || subscription.billing_product_price&.unit_amount&.zero?

      users = account.users.where('last_sign_in_at > ? ', total_no_days.days.ago)

      if users.present?
        if account.users.where('last_sign_in_at > ? ', no_days.days.ago).present?
          account.update(deletion_email_reminder: nil)
        end
      else
        user = account.account_users.where(inviter_id: nil).last&.user
        next if user.blank?

        AdministratorNotifications::AccountMailer.second_warning(account).deliver_now if user.created_at < no_days.days.ago
      end
    end
  end
end
