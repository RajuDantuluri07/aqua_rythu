-- Create expenses table for tracking operational costs
create table expenses (
  id uuid primary key default uuid_generate_v4(),
  
  user_id uuid not null,
  farm_id uuid not null,
  crop_id uuid not null,
  
  category text check (
    category in ('labour','electricity','diesel','sampling','other')
  ),
  
  amount numeric not null,
  notes text,
  
  date date not null default current_date,
  created_at timestamp default now()
);

-- Create index for efficient querying
create index idx_expenses_crop_date 
on expenses (crop_id, date);

-- Enable Row Level Security
alter table expenses enable row level security;

-- Create RLS policy for user access
create policy "user access expenses"
on expenses
for all
using (auth.uid() = user_id);

-- Add helpful comments
comment on table expenses is 'Tracks operational expenses for aquaculture farms';
comment on column expenses.category is 'Fixed categories: labour, electricity, diesel, sampling, other';
comment on column expenses.amount is 'Expense amount in local currency';
comment on column expenses.date is 'Date of expense (defaults to current date)';
