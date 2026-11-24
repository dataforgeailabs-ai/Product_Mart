from django.db import migrations, models


def customer_accounts_become_hotel(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    User.objects.filter(role="CUSTOMER").update(role="HOTEL")


def hotel_accounts_become_customer(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    User.objects.filter(role="HOTEL").update(role="CUSTOMER")


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_alter_user_role"),
    ]

    operations = [
        migrations.RunPython(
            customer_accounts_become_hotel,
            hotel_accounts_become_customer,
        ),
        migrations.AlterField(
            model_name="user",
            name="role",
            field=models.CharField(
                choices=[
                    ("SUPERADMIN", "Superadmin"),
                    ("ADMIN", "Admin"),
                    ("DELIVERY", "Delivery Person"),
                    ("HOTEL", "Hotel Staff"),
                ],
                default="HOTEL",
                max_length=20,
            ),
        ),
    ]
