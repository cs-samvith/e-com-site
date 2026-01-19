/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  // CRITICAL: Enable standalone output for Docker
  output: "standalone",

  // Disable ESLint during build (can cause webpack errors in pipelines)
  eslint: {
    ignoreDuringBuilds: true,
  },

  // TypeScript settings
  typescript: {
    ignoreBuildErrors: false,
  },

  // API rewrites - with safe fallback defaults
  async rewrites() {
    const userServiceUrl =
      process.env.NEXT_PUBLIC_USER_SERVICE_URL || "http://localhost:8080";
    const productServiceUrl =
      process.env.NEXT_PUBLIC_PRODUCT_SERVICE_URL || "http://localhost:8081";

    return [
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
