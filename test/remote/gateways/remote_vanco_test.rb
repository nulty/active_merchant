require 'test_helper'

class RemoteVancoTest < Test::Unit::TestCase
  def setup
    @gateway = VancoGateway.new(fixtures(:vanco))

    @amount = 10005
    @credit_card = credit_card('4111111111111111')

    @options = {
      order_id: '1',
      billing_address: address(country: "US", state: "NC", zip: "06085"),
      description: 'Store Purchase'
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, billing_address: address(country: "CA"))
    assert_failure response
    assert_equal("Client not set up for International Credit Card Processing", response.message)
    assert_equal("286", response.error_code)
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal "Success", refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount+500, purchase.authorization)
    assert_failure refund
    assert_match(/Amount Cannot Be Greater Than/, refund.message)
  end

  def test_invalid_login
    gateway = VancoGateway.new(
      user_id: '',
      password: '',
      client_id: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid SessionID", response.message
  end
end
