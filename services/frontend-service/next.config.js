/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  reactStrictMode: true,

  // Environment variables
  env: {
    NEXT_PUBLIC_USER_SERVICE_URL:
      process.env.NEXT_PUBLIC_USER_SERVICE_URL || "http://localhost:8080",
    NEXT_PUBLIC_PRODUCT_SERVICE_URL:
      process.env.NEXT_PUBLIC_PRODUCT_SERVICE_URL || "http://localhost:8081",
  },

  // Rewrites for API calls (proxy to backend services)
  async rewrites() {
    const userServiceUrl =
      process.env.NEXT_PUBLIC_USER_SERVICE_URL || "http://localhost:8080";
    const productServiceUrl =
      process.env.NEXT_PUBLIC_PRODUCT_SERVICE_URL || "http://localhost:8081";

    return [
      // Specific routes FIRST (before wildcards)
      {
        source: "/api/products/search",
        destination: `${productServiceUrl}/api/products/search/`,
      },
      // Then wildcard routes
      {
        source: "/api/users/:path*",
        destination: `${userServiceUrl}/api/users/:path*`,
      },
      {
        source: "/api/products/:path*",
        destination: `${productServiceUrl}/api/products/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
