import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Настраиваем корректное завершение работы приложения
  app.enableShutdownHooks();

  // Разрешаем запросы от frontend
  app.enableCors({
    origin: 'http://localhost:5173',
  });

  // Запускаем сервер
  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();


