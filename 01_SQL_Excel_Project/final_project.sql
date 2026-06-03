with 
-- Очищення та форматування даних користувачів
users_cleaned as 
( 
select 	
		cur.user_id,
		cur.promo_signup_flag,
		cur.signup_datetime,
		case   			 -- Виправляємо дати з некоректним роком (наприклад, 0025 -> 2025)
			when cur.au < '0100-01-01' 
			then (cur.au + INTERVAL '2000 years')::date
			else cur.au
		end as signup_date
from ( 
		-- Конвертуємо текстову дату в формат DATE, обробляючи роздільники '.' та '/' на '-'
		select *,
				to_date(translate(split_part(trim(signup_datetime), ' ',1), './' , '--'), 'DD-MM-YYYY') as au
		from cohort_users_raw) as cur
),
-- Очищення та фільтрація подій
event_cleaned as			
(
select *
from (select
		cer.user_id,		 
		cer.event_type,
		cer.event_datetime,	
		-- Виправляємо дати з некоректним роком (наприклад, 0025 -> 2025)
		case			
			when cer.ae < '0100-01-01'
			then (cer.ae + INTERVAL '2000 years')::date
			else cer.ae
		end as event_date
from (
		-- Конвертуємо текстову дату в формат DATE, обробляючи роздільники '.' та '/' на '-'
		select
				*,
				to_date(translate(split_part(trim(event_datetime), ' ',1), './' , '--'), 'DD-MM-YYYY') as ae
		from cohort_events_raw
		where event_type is not null and event_type != 'test_event' -- Фільтруємо тестові події та перетворюємо дату
	 ) as cer
) as asd
where event_date <= '2025-06-30' -- Фільтруємо лишні дати (майбутні періоди)
),
 -- Об'єднання даних для розрахунку когорт
user_activity as 
(
select 
		ec.user_id,
		date_trunc('month', uc.signup_date)::date as cohort_month,	-- Місяць реєстрації (когорта)
		uc.promo_signup_flag,
		date_trunc('month', ec.event_date)::date as activity_month,	-- Місяць активності
		-- Розрахунок різниці в місяцях між реєстрацією та подією
        (extract(month from ec.event_date) - extract(month from uc.signup_date)) as month_offset
from event_cleaned as ec
left join users_cleaned as uc on ec.user_id = uc.user_id
)
-- Фінальний результат: кількість унікальних користувачів у розрізі промо-мітки, когорт та зміщення
select 
    	promo_signup_flag,
		cohort_month,   
    	month_offset,
    	count(distinct user_id) as active_users
from user_activity
group by promo_signup_flag, cohort_month, month_offset
order by promo_signup_flag, cohort_month, month_offset
;
