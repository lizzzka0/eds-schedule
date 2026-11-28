import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { LessonsModule } from './lessons/lessons.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [LessonsModule, PrismaModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}

