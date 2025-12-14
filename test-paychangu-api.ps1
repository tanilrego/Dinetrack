$PAYCHANGU_API_KEY = $env:PAYCHANGU_API_KEY

if (-not $PAYCHANGU_API_KEY) {
    Write-Host "ERROR: PAYCHANGU_API_KEY environment variable not set" -ForegroundColor Red
    Write-Host "Please set it first: `$env:PAYCHANGU_API_KEY = 'your-api-key'" -ForegroundColor Yellow
    exit 1
}

Write-Host "Testing PayChangu API endpoints..." -ForegroundColor Cyan
Write-Host ""

# Test payload
$payload = @{
    amount = 10000  # 100 MWK in cents
    currency = "MWK"
    tx_ref = "test-" + (Get-Date -Format "yyyyMMddHHmmss")
    email = "test@example.com"
    first_name = "Test"
    last_name = "User"
    return_url = "https://example.com/return"
    callback_url = "https://example.com/callback"
} | ConvertTo-Json

Write-Host "Payload:" -ForegroundColor Yellow
Write-Host $payload
Write-Host ""

# Test different endpoints
$endpoints = @(
    "https://api.paychangu.com/v1/payments",
    "https://api.paychangu.com/v1/payment",
    "https://api.paychangu.com/payment/v1/initiate",
    "https://api.paychangu.com/payment/v1/transactions"
)

foreach ($endpoint in $endpoints) {
    Write-Host "-----------------------------------" -ForegroundColor Green
    Write-Host "Testing: $endpoint" -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $endpoint -Method POST `
            -Headers @{
                "Authorization" = "Bearer $PAYCHANGU_API_KEY"
                "Content-Type" = "application/json"
            } `
            -Body $payload `
            -ErrorAction Stop
        
        Write-Host "✓ SUCCESS - Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "Response: $($response.Content)" -ForegroundColor White
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        Write-Host "✗ FAILED - Status: $statusCode" -ForegroundColor Red
        
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Error: $responseBody" -ForegroundColor Yellow
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

Write-Host "-----------------------------------" -ForegroundColor Green
Write-Host "Testing complete!" -ForegroundColor Cyan
