# SignalHouse Ruby SDK

Official Ruby SDK for the [SignalHouse](https://signalhouse.io) SMS/MMS messaging API.

Full API reference and guides: https://app2.signalhouse.io/docs

## Installation

Add to your Gemfile:

```ruby
gem "signalhouse-sms"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install signalhouse-sms
```

## Quick Start

### Initialize the Client

```ruby
require "signalhouse_sms"

client = SignalHouseSms::Client.new(
  api_key: "your-api-key",
  base_url: "https://v2.signalhouse.io"
)
```

For admin operations (SignalHouse internal staff):

```ruby
client = SignalHouseSms::Client.new(
  api_key: "your-api-key",
  base_url: "https://v2.signalhouse.io",
  enable_admin: true
)
```

### Login

```ruby
result = client.auth.login(email: "user@example.com", password: "password123")

if result["success"]
  token = result["data"]["token"]
  puts "Logged in! Token: #{token}"
else
  puts "Login failed: #{result["error"]}"
end
```

### Send an SMS

```ruby
result = client.messages.send_sms(
  sender_phone_number: "15551234567",
  recipient_phone_numbers: ["15559876543"],
  message_body: "Hello from SignalHouse!",
  token: "your-jwt-token"
)

puts result
```

### Send an MMS with Images

```ruby
image_file = {
  filename: "photo.jpg",
  io: File.open("photo.jpg", "rb"),
  content_type: "image/jpeg"
}

result = client.messages.send_mms(
  sender_phone_number: "15551234567",
  recipient_phone_numbers: ["15559876543"],
  message_body: "Check out this photo!",
  images: [image_file],
  token: "your-jwt-token"
)

puts result
```

### List Phone Numbers

```ruby
result = client.numbers.get_phone_numbers(
  group_id: "G0000001",
  page: 1,
  limit: 20,
  token: "your-jwt-token"
)

if result["success"]
  result["data"]["data"].each do |number|
    puts number["phoneNumber"]
  end
end
```

### Purchase Phone Numbers

```ruby
result = client.numbers.purchase_phone_number(
  phone_numbers: ["15551234567"],
  subgroup_id: "SG000001",
  token: "your-jwt-token"
)

puts result
```

### Create a Brand

```ruby
result = client.brands.create_brand(
  brand_data: {
    subgroupId: "SG000001",
    entityType: "PRIVATE_PROFIT",
    displayName: "My Brand",
    companyName: "My Company Inc",
    ein: "123456789",
    phone: "15551234567",
    street: "123 Main St",
    city: "New York",
    state: "NY",
    postalCode: "10001",
    country: "US",
    email: "contact@mycompany.com",
    vertical: "TECHNOLOGY"
  },
  token: "your-jwt-token"
)

puts result
```

### List Toll-Free Business Verifications

When `required` is true, each new toll-free brand names a `VERIFIED` business verification as `tollFree.businessVerificationId`; add one with `create_business_verification`. Some groups verify each subgroup's business separately: a platform whose subgroups are separate businesses, set up by Signal House. For those groups `subgroup_id` is required, on both methods, and the response includes `subgroupId`.

```ruby
result = client.brands.get_business_verifications(
  group_id: "G0000001",
  subgroup_id: "SG000001", # required when the group verifies each subgroup's business separately
  token: "your-jwt-token"
)

if result["success"]
  result["data"]["businessVerifications"].each do |verification|
    puts "#{verification['businessVerificationId']}: #{verification['status']}"
  end
end
```

### Using Token Override

All methods accept a `token:` keyword to override the API key for that specific request. This is useful when making requests on behalf of authenticated users:

```ruby
# Use the client's api_key (default)
result = client.brands.get_brands

# Override with a specific user token
result = client.brands.get_brands(token: "user-jwt-token")
```

### Custom Headers

All methods accept a `headers:` keyword to add custom headers:

```ruby
result = client.brands.get_brands(
  token: "user-jwt-token",
  headers: { "X-Request-Id" => "abc123" }
)
```

## Admin Methods

When `enable_admin: true` is set, admin-scoped methods are available on domains that support them:

```ruby
client = SignalHouseSms::Client.new(
  api_key: "admin-api-key",
  base_url: "https://v2.signalhouse.io",
  enable_admin: true
)

# Admin: list all groups
client.groups.admin.get_groups(page: 1, limit: 50, token: admin_token)

# Admin: approve a campaign
client.campaigns.admin.approve_campaign(campaign_id: "C123", token: admin_token)

# Admin: create subscription template
client.subscriptions.admin.create_template(
  template_data: { templateName: "Pro Plan", monthlyFee: 50_000_000 },
  token: admin_token
)

# Admin: create internal user
client.users.admin.create_internal_user(
  data: { email: "admin@signalhouse.io", role: "signalhouse_admin" },
  token: admin_token
)
```

## Available Domains

| Domain | Accessor | Methods |
|--------|----------|---------|
| Auth | `client.auth` | `login`, `reset_password`, `get_auth_history` |
| Billing | `client.billing` | `get_transaction_history`, `get_wallet`, `update_wallet`, `get_payment_methods`, `add_funds`, `add_payment_method`, `remove_payment_method`, `get_invoice_details`, `get_fees` |
| Brands | `client.brands` | `get_brands`, `get_external_vetting`, `create_brand`, `get_business_verifications`, `get_business_verification`, `create_business_verification`, `update_business_verification`, `get_toll_free_isv_account` (staff only), `set_toll_free_isv_account` (staff only), `transfer_brand`, `create_external_vetting`, `update_brand`, `revet_brand`, `delete_brand` |
| Campaigns | `client.campaigns` | `get_campaigns`, `create_campaign`, `update_campaign`, `delete_campaign` |
| Campaigns Admin | `client.campaigns.admin` | `approve_campaign`, `reject_campaign` |
| Groups | `client.groups` | `get_group`, `update_group` |
| Groups Admin | `client.groups.admin` | `get_groups`, `create_group`, `delete_group` |
| Landings | `client.landings` | `get_landings`, `get_public_landing`, `create_landing`, `update_landing`, `get_landing_by_brand_id`, `delete_landing` |
| Messages | `client.messages` | `get_messages`, `get_analytics`, `send_sms`, `send_mms`, `send_group_message`, `get_p2p_batch` |
| Notifications | `client.notifications` | `get_notifications`, `update_notification_status`, `delete_notification` |
| Numbers | `client.numbers` | `get_phone_numbers`, `get_number_health`, `get_available_phone_numbers`, `purchase_phone_number`, `update_phone_number`, `get_caller_name`, `set_caller_name`, `delete_caller_name`, `port_in_phone_number`, `assign_phone_number_to_campaign`, `unassign_phone_numbers_from_campaigns`, `delete_phone_numbers`, `transfer_phone_numbers`, `search_npa_nxx`, `lookup_locations` |
| Shortlinks | `client.shortlinks` | `get_shortlink_redirect`, `get_shortlink` |
| Subgroups | `client.subgroups` | `get_subgroups`, `create_subgroup`, `update_subgroup`, `delete_subgroup` |
| Subscriptions | `client.subscriptions` | `get_subscriptions`, `subscribe`, `unsubscribe` |
| Subscriptions Admin | `client.subscriptions.admin` | `get_templates`, `create_template`, `update_template`, `delete_template`, `create_custom_subscription` |
| Templates | `client.templates` | `create`, `list`, `get`, `update`, `publish`, `archive`, `versions`, `validate`, `capabilities`, `upload_media` |
| Users | `client.users` | `get_users`, `create_user`, `create_service_user`, `update_user`, `delete_user`, `get_notification_preferences`, `update_notification_preferences` |
| Users Admin | `client.users.admin` | `get_users`, `create_internal_user` |
| Webhooks | `client.webhooks` | `get_webhooks`, `create_webhook`, `update_webhook`, `delete_webhook` |

## Error Handling

```ruby
begin
  result = client.messages.send_sms(
    sender_phone_number: "15551234567",
    recipient_phone_numbers: ["15559876543"],
    message_body: "Hello!"
  )
rescue SignalHouseSms::ValidationError => e
  puts "Validation error: #{e.message} (status: #{e.status})"
rescue SignalHouseSms::Error => e
  puts "SignalHouse error: #{e.message} (status: #{e.status})"
end
```

## Response Format

All methods return a standardized hash:

**Success:**
```ruby
{
  "success" => true,
  "data"    => { ... },   # Parsed JSON response body
  "status"  => 200        # HTTP status code
}
```

**Error:**
```ruby
{
  "success" => false,
  "error"   => "Error message",
  "status"  => 400        # HTTP status code
}
```

## Requirements

- Ruby >= 3.0.0
- No external dependencies (uses `net/http` and `json` from stdlib)

## License

MIT
