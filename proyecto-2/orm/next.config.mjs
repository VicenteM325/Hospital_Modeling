/** @type {import('next').NextConfig} */
const nextConfig = {
  // TypeORM y pg se cargan desde node_modules en el servidor (no se empaquetan en el bundle)
  serverExternalPackages: ['typeorm', 'pg'],
  poweredByHeader: false,
};

export default nextConfig;
