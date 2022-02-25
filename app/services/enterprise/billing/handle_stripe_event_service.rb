class Enterprise::Billing::HandleStripeEventService
  def call(event:)
    if event['data']['object']['metadata']['website'] == 'OneChat'
      case event.type
      when 'customer.subscription.created'
        subscription = event.data.object
        account = Account.where("custom_attributes->>'stripe_customer_id' = ?", subscription.customer).first
        subscription_price = Enterprise::BillingProductPrice.find_by(price_stripe_id: subscription.plan.id)
        account.account_billing_subscriptions.create!(billing_product_price: subscription_price, subscription_stripe_id: subscription.id,
                                                      current_period_end: Time.at(subscription.current_period_end).utc.to_datetime)
      else
        Rails.logger.debug { "Unhandled event type: #{event.type}" }
      end
    end
  end
end
