import type { ReactNode } from 'react';
import './globals.css';

export const metadata = {
  title: 'Hospitales de Occidente - SQL vs ORM',
  description: 'Objetivos 2, 8 y 11 del Proyecto 2 resueltos con SQL parametrizado y con TypeORM',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
