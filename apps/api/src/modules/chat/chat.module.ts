import { Module } from '@nestjs/common';
import { ExercisesModule } from '../exercises/exercises.module';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';

@Module({
  imports: [ExercisesModule],
  controllers: [ChatController],
  providers: [ChatService],
})
export class ChatModule {}
