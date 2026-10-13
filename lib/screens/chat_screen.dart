import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final String incidentId;
  final String category;
  final bool isAdmin;
  final String? studentId;

  const ChatScreen({
    super.key,
    required this.incidentId,
    required this.category,
    required this.isAdmin,
    this.studentId,
  });

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState
    extends State<ChatScreen> {
  final TextEditingController
  _messageController =
  TextEditingController();

  final ScrollController
  _scrollController =
  ScrollController();

  final MessageService
  _messageService =
  MessageService();

  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> _sendMessage() async {
    final text =
    _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    String receiverId = '';

    if (widget.isAdmin) {
      if (widget.studentId == null ||
          widget.studentId!.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Student ID is missing.',
            ),
          ),
        );

        return;
      }

      receiverId =
      widget.studentId!;
    } else {
      // -------------------------------------------------------
      // For student messages:
      // We use the incident's assignedStaffId if available.
      // If no staff is assigned yet, the message is not sent.
      // -------------------------------------------------------

      try {
        final incident =
        await FirebaseFirestore
            .instance
            .collection('incidents')
            .doc(widget.incidentId)
            .get();

        final data =
        incident.data();

        if (data == null) {
          throw Exception(
            'Incident not found.',
          );
        }

        receiverId =
            data['assignedStaffId'] ?? '';

        if (receiverId.isEmpty) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Your report has not been assigned to staff yet.',
              ),
            ),
          );

          return;
        }
      } catch (e) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Unable to send message: $e',
            ),
          ),
        );

        return;
      }
    }

    setState(() {
      _sending = true;
    });

    try {
      final messageId =
          FirebaseFirestore.instance
              .collection('messages')
              .doc()
              .id;

      final message =
      MessageModel(
        id: messageId,
        incidentId:
        widget.incidentId,
        senderId:
        user.uid,
        receiverId:
        receiverId,
        message: text,
        createdAt:
        DateTime.now(),
        isRead: false,
      );

      await _messageService
          .sendMessage(
        message,
      );

      _messageController.clear();

      await Future.delayed(
        const Duration(
          milliseconds: 100,
        ),
      );

      if (_scrollController
          .hasClients) {
        _scrollController
            .animateTo(
          _scrollController
              .position
              .maxScrollExtent,

          duration:
          const Duration(
            milliseconds: 300,
          ),

          curve:
          Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send message: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in first.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar: AppBar(
        title: Text(
          'Chat - ${widget.category}',
        ),

        backgroundColor:
        AppColors.umBlue,

        foregroundColor:
        AppColors.white,
      ),

      body: Column(
        children: [
          // ===================================================
          // INCIDENT HEADER
          // ===================================================

          Container(
            width:
            double.infinity,

            padding:
            const EdgeInsets.all(14),

            color:
            AppColors.umLightBlue,

            child: Row(
              children: [
                const Icon(
                  Icons.report,
                  color:
                  AppColors.umBlue,
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    'Incident: ${widget.category}',
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      color:
                      AppColors.umDarkBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===================================================
          // MESSAGES
          // ===================================================

          Expanded(
            child: StreamBuilder<
                List<MessageModel>>(
              stream:
              _messageService
                  .getMessagesForIncident(
                widget.incidentId,
              ),

              builder: (
                  context,
                  snapshot,
                  ) {
                if (snapshot
                    .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                      const EdgeInsets
                          .all(20),
                      child: Text(
                        'Unable to load messages.\n\n'
                            '${snapshot.error}',
                        textAlign:
                        TextAlign.center,
                      ),
                    ),
                  );
                }

                final messages =
                    snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        Icon(
                          Icons
                              .chat_bubble_outline,
                          size: 60,
                          color:
                          AppColors.grey,
                        ),

                        SizedBox(
                          height: 12,
                        ),

                        Text(
                          'No messages yet.',
                          style:
                          TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        SizedBox(
                          height: 5,
                        ),

                        Text(
                          'You can send a message to the assigned staff.',
                          textAlign:
                          TextAlign.center,
                          style:
                          TextStyle(
                            color:
                            AppColors
                                .grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller:
                  _scrollController,

                  padding:
                  const EdgeInsets
                      .all(16),

                  itemCount:
                  messages.length,

                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    final message =
                    messages[index];

                    final isMine =
                        message.senderId ==
                            currentUser
                                .uid;

                    return _buildMessageBubble(
                      message,
                      isMine,
                    );
                  },
                );
              },
            ),
          ),

          // ===================================================
          // MESSAGE INPUT
          // ===================================================

          Container(
            padding:
            const EdgeInsets
                .fromLTRB(
              12,
              8,
              12,
              12,
            ),

            color:
            AppColors.white,

            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment
                  .end,

              children: [
                Expanded(
                  child:
                  TextField(
                    controller:
                    _messageController,

                    maxLines: 4,
                    minLines: 1,

                    textInputAction:
                    TextInputAction
                        .newline,

                    decoration:
                    InputDecoration(
                      hintText:
                      'Type a message...',

                      filled: true,

                      fillColor:
                      AppColors
                          .lightGrey,

                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          20,
                        ),

                        borderSide:
                        BorderSide.none,
                      ),

                      contentPadding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                CircleAvatar(
                  backgroundColor:
                  AppColors.umBlue,

                  child:
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        AppColors
                            .white,
                      ),
                    )
                        : const Icon(
                      Icons.send,
                      color:
                      AppColors
                          .white,
                    ),

                    onPressed:
                    _sending
                        ? null
                        : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MESSAGE BUBBLE
  // =========================================================

  Widget _buildMessageBubble(
      MessageModel message,
      bool isMine,
      ) {
    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child: Container(
        constraints:
        const BoxConstraints(
          maxWidth: 300,
        ),

        margin:
        const EdgeInsets.only(
          bottom: 10,
        ),

        padding:
        const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        decoration:
        BoxDecoration(
          color: isMine
              ? AppColors.umBlue
              : AppColors.white,

          borderRadius:
          BorderRadius.circular(
            16,
          ),

          border: isMine
              ? null
              : Border.all(
            color:
            AppColors
                .borderGrey,
          ),
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Text(
              message.message,

              style: TextStyle(
                color: isMine
                    ? AppColors.white
                    : AppColors.black,

                fontSize: 15,
              ),
            ),

            if (message.createdAt !=
                null)
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 5,
                ),

                child: Text(
                  _formatTime(
                    message.createdAt!,
                  ),

                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? Colors.white70
                        : AppColors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(
      DateTime date,
      ) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}