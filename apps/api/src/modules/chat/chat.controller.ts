import { Body, Controller, Post } from '@nestjs/common';
import { ChatRequestDto } from './chat.dto';
import { ChatService } from './chat.service';

@Controller('ai')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post('chat')
  async chat(@Body() dto: ChatRequestDto) {
    return this.chatService.handle(dto);
  }
}
