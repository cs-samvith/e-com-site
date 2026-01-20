/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: "standalone",
  eslint: { ignoreDuringBuilds: true },

  async rewrites() {
    // Use localhost for development, service names for production
    const isDev = process.env.NODE_ENV !== "production";

    return [
      {
        source: "/api/users/:path*",
        destination: isDev
          ? "http://localhost:8080/api/users/:path*"
          : "http://user-service:8080/api/users/:path*",
      },
      {
        source: "/api/products/:path*",
        destination: isDev
          ? "http://localhost:8081/api/products/:path*"
          : "http://product-service:8081/api/products/:path*",
      },
    ];
  },
};

module.exports = nextConfig;
