# Post-Creation Instructions

Guidelines for running, testing, and developing your project using FastEndpoints, Scalar, and TUnit.

## 1. Run the API

Navigate to the project root directory and run:

```bash
# If created with a solution structure:
dotnet run --project src/MyApi

# If created without a solution structure:
dotnet run --project MyApi
```

Check the terminal output for the active URL and port (defaults to `http://localhost:5000` or `https://localhost:5001`).

## 2. Test the Endpoints

After starting the API, test the sample endpoint in your browser or an HTTP client (cURL, Postman):

- **Sample Endpoint:** `GET http://localhost:5000/api/ping`
  Expected response:

  ```json
  {
    "message": "Pong",
    "timestamp": "2026-11-07T12:00:00Z"
  }
  ```

- **API Documentation via Scalar:**
  Access `http://localhost:5000/scalar/v1` to view the interactive documentation powered by the OpenAPI document generated at `/openapi/v1.json`.

## 3. Run Tests (TUnit)

Run tests with TUnit via Microsoft Testing Platform from the project root:

```bash
dotnet test
```

Or execute the test project directly:

```bash
dotnet run --project tests/MyApi.Tests
```

## 4. Create New Endpoints

FastEndpoints follows the REPR (Request-Endpoint-Response) pattern. Each endpoint is an isolated class:

```csharp
using FastEndpoints;

namespace MyApi.Endpoints;

public class GreetingEndpoint : EndpointWithoutRequest<GreetingResponse>
{
    public override void Configure()
    {
        Get("/api/greeting");
        AllowAnonymous();
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        await Send.OkAsync(
            new GreetingResponse("Hello World!"),
            ct);
    }
}

public record GreetingResponse(string Message);
```

## 5. Write Tests with TUnit

Example unit test testing the endpoint response:

```csharp
namespace MyApi.Tests;

public class PingTests
{
    [Test]
    public async Task PingEndpoint_ReturnsSuccess()
    {
        var timestamp = DateTime.UtcNow;

        var response = new MyApi.Endpoints.PingResponse(
            "Pong",
            timestamp);

        await Assert.That(response.Message)
            .IsEqualTo("Pong");

        await Assert.That(response.Timestamp)
            .IsEqualTo(timestamp);
    }
}
```

## 6. Project Structure

When created with the solution and test options enabled:

```text
MyApi/
├── Directory.Build.props
├── global.json
├── MyApi.sln
├── src/
│   └── MyApi/
│       ├── MyApi.csproj
│       ├── Program.cs
│       └── Endpoints/
│           └── PingEndpoint.cs
└── tests/
    └── MyApi.Tests/
        ├── MyApi.Tests.csproj
        └── PingTests.cs
```

## 7. Useful Resources

- [FastEndpoints Documentation](https://fast-endpoints.com/)
- [Scalar Documentation](https://scalar.com/)
- [TUnit Documentation](https://tunit.dev/)
