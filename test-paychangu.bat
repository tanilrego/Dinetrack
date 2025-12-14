@echo off
echo Testing PayChangu API endpoints...
echo.
echo NOTE: Make sure you have set your PAYCHANGU_API_KEY environment variable!
echo.

if "%PAYCHANGU_API_KEY%"=="" (
    echo ERROR: PAYCHANGU_API_KEY is not set!
    echo Set it with: set PAYCHANGU_API_KEY=your-key-here
    exit /b 1
)

echo Testing endpoint: /v1/payments
curl -X POST https://api.paychangu.com/v1/payments ^
    -H "Authorization: Bearer %PAYCHANGU_API_KEY%" ^
    -H "Content-Type: application/json" ^
    -d "{\"amount\":10000,\"currency\":\"MWK\",\"tx_ref\":\"test-123\",\"email\":\"test@example.com\",\"first_name\":\"Test\",\"last_name\":\"User\"}"

echo.
echo.
echo Done!
pause
