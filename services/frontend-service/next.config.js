/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  reactStrictMode: true,
  // Environment variables available to the browser
  env: {
    NEXT_PUBLIC_USER_SERVICE_URL:
      process.env.NEXT_PUBLIC_USER_SERVICE_URL || "http: //localhost:8080",
    NEXT_PUBLIC_PRODUCT_SERVICE_URL:
      process.env.NEXT_PUBLIC_PRODUCT_SERVICE_URL || "http: //localhost:8081",
  },
  // Rewrites for API calls (proxy to backend services)
  async rewrites() {
    return [
      {
        source: "/api/users/:path*",
        destination: `${
          process.env.NEXT_PUBLIC_USER_SERVICE_URL
        }/api/users/:path*`,
      },
      {
        source: "/api/products/:path*",
        destination: `${
          process.env.NEXT_PUBLIC_PRODUCT_SERVICE_URL
        }/api/products/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
