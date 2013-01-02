require 'mechanize'
require 'nokogiri'
require 'trollop'

FIRST_STORE = 'ctl00$ContentPlaceHolder1$ctl12$rptStores$ctl01$cmdSelectStore'

def login(agent, page, store)
  pickup_page = agent.click(page.link_with(:id => 'lnkPickup'))
  login_form = pickup_page.form_with(:method => 'POST')
  login_form.field_with(:id => 'txtCustomerName').value = 'Joe'
  login_form.field_with(:id => 'txtPhoneNumber').value = '0123456789'
  login_form.field_with(:id => 'txtPickupStore').value = 'Woolloongabba'
  login_form.field_with(:id => 'txtEmail').value = 'email@email.com'
  store_search_page = login_form.submit(login_form.button_with(:id => 'cmdSubmit'))
  store_search_form = store_search_page.form_with(:method => 'POST')
  confirm_pickup_page = store_search_form.submit(store_search_form.button_with(:name => FIRST_STORE))
  confirm_pickup_form = confirm_pickup_page.form_with(:method => 'POST')
  pickup_time_page = confirm_pickup_form.submit(confirm_pickup_form.button_with(:id => 'cmdSubmit'))
  pickup_time_form = pickup_time_page.form_with(:method => 'POST')
  return pickup_time_form.submit(pickup_time_form.button_with(:id => 'cmdPickupAsap'))
end

def test_codes(codes, opts)
  agent = Mechanize.new { |agent|
    agent.user_agent_alias = 'Mac Safari'
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  }

  agent.get('https://internetorder.dominos.com.au/Accessible/select-service#top') do |page|
    order_page = login(agent, page, opts[:store])
    codes.each do |code|
      order_form = order_page.form_with(:method => 'POST')
      order_form.field_with(:id => 'txtVoucher').value = "%05d" % code
      order_page = order_form.submit(order_form.button_with(:id => 'cmdAdd'))
      doc = Nokogiri::HTML(order_page.body)
      voucher_note = doc.at_css("li.help").text
      if (opts[:include_invalid] || nil != doc.css("li.voucher-item").first)
        printf "[%05d] - %s\n", code, voucher_note
      end
      order_form = order_page.form_with(:method => 'POST')
      order_form.checkboxes_with(:name => /ctl00/).each do |field| field.check end
      order_page = order_form.submit(order_form.button_with(:id => 'cmdRemoveItems'))
    end
  end
end

opts = Trollop::options do
  opt :store, "Store name", :type => :string, :required => true
  opt :threads, "Number of items per thread", :default => 25000
  opt :include_invalid, "Include 'invalid' codes"
end

codes = (0..99999)
threads = []

codes.each_slice(opts[:threads]) do |code_range|
  threads << Thread.new do
    test_codes(code_range, opts)
  end
end

threads.each{ |thread| thread.join}
