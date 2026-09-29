using System.Text.Json;
using Amazon.S3;
using Amazon.S3.Model;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://0.0.0.0:8080");
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower);
builder.Services.AddSingleton<IAmazonS3, AmazonS3Client>();

var app = builder.Build();

var bucket = Environment.GetEnvironmentVariable("S3_BUCKET")
    ?? throw new InvalidOperationException("S3_BUCKET is not set");
var region = Environment.GetEnvironmentVariable("AWS_REGION")
    ?? throw new InvalidOperationException("AWS_REGION is not set");

var ads = new List<Ad>();

app.MapGet("/ads", () =>
    ads.Count == 0 ? Results.NotFound() : Results.Ok(ads[Random.Shared.Next(ads.Count)]));

app.MapPost("/ads", async (HttpRequest request, IAmazonS3 s3, ILogger<Program> logger) =>
{
    var form = await request.ReadFormAsync();
    var title = form["title"].ToString();
    var content = form["content"].ToString();
    var image = form.Files["image"];

    if (string.IsNullOrWhiteSpace(title) || string.IsNullOrWhiteSpace(content) || image is null || image.Length == 0)
        return Results.BadRequest();
    if (image.ContentType is not "image/jpeg" and not "image/png" and not "image/webp")
        return Results.BadRequest();

    var id = Guid.NewGuid().ToString();
    var key = $"ads/{id}";

    try
    {
        using var stream = image.OpenReadStream();
        await s3.PutObjectAsync(new PutObjectRequest
        {
            BucketName = bucket,
            Key = key,
            InputStream = stream,
            ContentType = image.ContentType
        });

        var ad = new Ad(id, title, content, $"https://{bucket}.s3.{region}.amazonaws.com/{key}");

        ads.Add(ad);
        return Results.Created("/ads", ad);
    }
    catch (AmazonS3Exception ex)
    {
        logger.LogError(ex, "Failed to upload ad image to S3 with key {Key}", key);
        return Results.Problem();
    }
});

app.Run();

record Ad(string Id, string Title, string Content, string ImageUrl);
