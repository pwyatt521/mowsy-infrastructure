-- Add notifications system
-- Migration: 002_add_notifications.sql

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL CHECK (type IN ('job_application', 'job_assigned', 'job_completed', 'equipment_request', 'equipment_approved', 'payment_received', 'review_received', 'system_announcement')),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    read_at TIMESTAMP WITH TIME ZONE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Notification preferences table
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email_job_applications BOOLEAN DEFAULT TRUE,
    email_job_assignments BOOLEAN DEFAULT TRUE,
    email_equipment_requests BOOLEAN DEFAULT TRUE,
    email_payments BOOLEAN DEFAULT TRUE,
    email_reviews BOOLEAN DEFAULT TRUE,
    email_marketing BOOLEAN DEFAULT FALSE,
    push_job_applications BOOLEAN DEFAULT TRUE,
    push_job_assignments BOOLEAN DEFAULT TRUE,
    push_equipment_requests BOOLEAN DEFAULT TRUE,
    push_payments BOOLEAN DEFAULT TRUE,
    push_reviews BOOLEAN DEFAULT TRUE,
    sms_job_assignments BOOLEAN DEFAULT FALSE,
    sms_equipment_requests BOOLEAN DEFAULT FALSE,
    sms_payments BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Create indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Create trigger for notification_preferences updated_at
CREATE TRIGGER update_notification_preferences_updated_at 
    BEFORE UPDATE ON notification_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();