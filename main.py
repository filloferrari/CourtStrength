import json
import re
from kivy.clock import Clock
from kivy.lang import Builder
from kivymd.app import MDApp
from kivymd.uix.screen import MDScreen
from kivy.uix.screenmanager import ScreenManager
from kivy.uix.popup import Popup
from kivy.uix.label import Label
from kivy.metrics import dp
from kivy.core.window import Window
from kivy.properties import StringProperty, NumericProperty, ListProperty, BooleanProperty, ObjectProperty
from kivymd.uix.card import MDCard

# Impostiamo le proporzioni del telefono per il test su PC
Window.size = (360, 640)

# --- CLASSE CARD DELLA HOME ---
class WorkoutListCard(MDCard):
    workout_data = ObjectProperty(None)
    title_text = StringProperty("")
    subtitle_text = StringProperty("")
    stats_text = StringProperty("")
    
    def on_release(self):
        # Quando viene premuta, avvia l'allenamento passandogli i propri dati
        MDApp.get_running_app().start_workout(self.workout_data)

# --- CLASSE CARD DELL'ESERCIZIO ---
class ExerciseCard(MDCard):
    block_id = StringProperty("")
    category = StringProperty("")
    name_ex = StringProperty("")
    desc = StringProperty("")
    
    target_sets = NumericProperty(0)
    current_set = NumericProperty(0)
    reps_str = StringProperty("")
    
    weight = NumericProperty(0)
    weight_str = StringProperty("0")
    rest_time = NumericProperty(0)
    
    color_theme = ListProperty([0.8, 1, 0.2, 1])
    is_last_in_block = BooleanProperty(True)
    
    def on_weight(self, instance, value):
        self.weight_str = f"{value:g}"
        
    def adjust_weight(self, amount):
        self.weight += amount
        if self.weight < 0:
            self.weight = 0

class WindowManager(ScreenManager):
    pass

class HomeScreen(MDScreen):
    pass

class WorkoutScreen(MDScreen):
    pass

# --- VIEW (Interfaccia Grafica) ---
KV = '''
# Template per la Card nella schermata Home
<WorkoutListCard>:
    orientation: 'vertical'
    size_hint_y: None
    height: "130dp"
    padding: "20dp"
    spacing: "8dp"
    radius: [15, 15, 15, 15]
    md_bg_color: 0.12, 0.12, 0.12, 1
    line_color: 0.8, 1, 0.2, 1 # Bordo verde fluo
    ripple_behavior: True # Effetto click fluido
    
    MDLabel:
        text: root.subtitle_text
        font_style: "Label"
        role: "small"
        theme_text_color: "Custom"
        text_color: 0.8, 1, 0.2, 1
        bold: True
        size_hint_y: None
        height: self.texture_size[1]
        
    MDLabel:
        text: root.title_text
        font_style: "Title"
        role: "large"
        bold: True
        theme_text_color: "Custom"
        text_color: 1, 1, 1, 1
        
    MDBoxLayout:
        orientation: "horizontal"
        size_hint_y: None
        height: "20dp"
        spacing: "10dp"
        
        MDIcon:
            icon: "dumbbell"
            theme_text_color: "Custom"
            text_color: 0.5, 0.5, 0.5, 1
            size_hint_x: None
            width: "20dp"
        
        MDLabel:
            text: root.stats_text
            font_style: "Body"
            role: "small"
            theme_text_color: "Custom"
            text_color: 0.5, 0.5, 0.5, 1

# Template per la Card dell'Esercizio
<ExerciseCard>:
    orientation: 'vertical'
    size_hint_y: None
    height: "330dp"
    padding: "15dp"
    spacing: "8dp"
    radius: [15, 15, 15, 15]
    md_bg_color: 0.12, 0.12, 0.12, 1
    line_color: root.color_theme
    
    MDLabel:
        text: root.category
        font_style: "Label"
        role: "small"
        theme_text_color: "Custom"
        text_color: root.color_theme
        bold: True
        size_hint_y: None
        height: self.texture_size[1]
        
    MDLabel:
        text: root.name_ex
        font_style: "Title"
        role: "large"
        bold: True
        theme_text_color: "Custom"
        text_color: 1, 1, 1, 1
        size_hint_y: None
        height: self.texture_size[1]
        
    MDLabel:
        text: root.desc
        font_style: "Body"
        role: "small"
        theme_text_color: "Custom"
        text_color: 0.6, 0.6, 0.6, 1
        size_hint_y: None
        height: self.texture_size[1]
        
    MDBoxLayout:
        size_hint_y: None
        height: "40dp"
        spacing: "5dp"
        
        MDLabel:
            text: f"REPS: {root.reps_str}"
            font_style: "Body"
            role: "small"
            theme_text_color: "Custom"
            text_color: 0.5, 0.5, 0.5, 1
            size_hint_x: 0.4
            
        MDIconButton:
            icon: "minus"
            theme_text_color: "Custom"
            text_color: 1, 1, 1, 1
            on_release: root.target_sets = max(1, root.target_sets - 1)
            
        MDLabel:
            text: f"SERIE: {root.current_set} / {root.target_sets}"
            halign: "center"
            bold: True
            theme_text_color: "Custom"
            text_color: (0.8, 1, 0.2, 1) if root.current_set >= root.target_sets else (1, 1, 1, 1)
            
        MDIconButton:
            icon: "plus"
            theme_text_color: "Custom"
            text_color: 1, 1, 1, 1
            on_release: root.target_sets += 1
        
    MDBoxLayout:
        orientation: 'horizontal'
        size_hint_y: None
        height: "50dp"
        spacing: "15dp"
        
        MDButton:
            style: "filled"
            theme_width: "Custom"
            md_bg_color: 0.2, 0.2, 0.2, 1
            on_release: root.adjust_weight(-2.5)

            MDButtonText:
                text: "-"
                font_size: "20sp"

        MDLabel:
            text: root.weight_str + " KG"
            halign: "center"
            font_style: "Title"
            role: "large"
            bold: True
            theme_text_color: "Custom"
            text_color: 1, 1, 1, 1

        MDButton:
            style: "filled"
            theme_width: "Custom"
            md_bg_color: 0.2, 0.2, 0.2, 1
            on_release: root.adjust_weight(2.5)

            MDButtonText:
                text: "+"
                font_size: "20sp"

    MDButton:
        style: "filled"
        size_hint_x: 1
        md_bg_color: 0.2, 0.2, 0.2, 1
        on_release: app.start_timer(root.rest_time, root.block_id) if root.is_last_in_block else app.next_in_superset()

        MDButtonText:
            text: f"COMPLETA BLOCCO ({root.rest_time}s)" if root.is_last_in_block else "PROSSIMO (NO PAUSA)"
            theme_text_color: "Custom"
            text_color: root.color_theme

<WindowManager>:
    HomeScreen:
        name: 'home'
    WorkoutScreen:
        name: 'workout'

<HomeScreen>:
    MDBoxLayout:
        orientation: 'vertical'
        md_bg_color: 0.05, 0.05, 0.05, 1

        MDBoxLayout:
            size_hint_y: None
            height: "70dp"
            padding: ["20dp", "20dp", "20dp", "10dp"]
            md_bg_color: 0.05, 0.05, 0.05, 1
            
            MDLabel:
                text: "COURT STRENGTH"
                font_style: "Title"
                role: "medium"
                theme_text_color: "Custom"
                text_color: 0.8, 1, 0.2, 1
                bold: True

        MDScrollView:
            MDBoxLayout:
                id: workout_list
                orientation: 'vertical'
                padding: ["20dp", "10dp", "20dp", "20dp"]
                spacing: "20dp"
                adaptive_height: True
                
                MDLabel:
                    text: "I tuoi programmi"
                    font_style: "Body"
                    role: "large"
                    theme_text_color: "Custom"
                    text_color: 1, 1, 1, 1
                    bold: True
                    size_hint_y: None
                    height: "30dp"

<WorkoutScreen>:
    MDBoxLayout:
        orientation: 'vertical'
        md_bg_color: 0.08, 0.08, 0.08, 1

        MDBoxLayout:
            size_hint_y: None
            height: "60dp"
            padding: ["15dp", "10dp", "15dp", "10dp"]
            md_bg_color: 0.08, 0.08, 0.08, 1
            
            MDLabel:
                text: "COURT STRENGTH"
                font_style: "Body"
                role: "medium"
                theme_text_color: "Custom"
                text_color: 0.8, 1, 0.2, 1
                bold: True
                
            MDIconButton:
                icon: "close"
                theme_text_color: "Custom"
                text_color: 1, 1, 1, 1
                pos_hint: {"center_y": .5}
                on_release: app.go_home()

        MDScrollView:
            MDBoxLayout:
                orientation: 'vertical'
                padding: ["20dp", "10dp", "20dp", "20dp"]
                spacing: "15dp"
                adaptive_height: True

                MDLabel:
                    id: workout_subtitle
                    text: ""
                    font_style: "Label"
                    role: "small"
                    theme_text_color: "Custom"
                    text_color: 0.8, 1, 0.2, 1
                    bold: True
                    size_hint_y: None
                    height: self.texture_size[1]
                    
                MDLabel:
                    id: workout_title
                    text: ""
                    font_style: "Headline"
                    role: "small"
                    theme_text_color: "Custom"
                    text_color: 1, 1, 1, 1
                    bold: True
                    size_hint_y: None
                    height: self.texture_size[1]
                    
                MDLabel:
                    id: workout_desc
                    text: ""
                    font_style: "Body"
                    role: "small"
                    theme_text_color: "Custom"
                    text_color: 0.6, 0.6, 0.6, 1
                    size_hint_y: None
                    height: self.texture_size[1]
                    
                MDBoxLayout:
                    size_hint_y: None
                    height: "30dp"
                    spacing: "10dp"
                    MDLabel:
                        id: workout_stats
                        text: "--- MIN  |  --- ESERCIZI"
                        font_style: "Body"
                        role: "small"
                        bold: True
                        theme_text_color: "Custom"
                        text_color: 0.8, 1, 0.2, 1

                MDBoxLayout:
                    id: exercises_container
                    orientation: 'vertical'
                    spacing: "25dp"
                    adaptive_height: True

        MDBoxLayout:
            size_hint_y: None
            height: "80dp"
            padding: "10dp"
            spacing: "10dp"
            md_bg_color: 0.15, 0.15, 0.15, 1
            orientation: "horizontal"

            MDButton:
                style: "filled"
                md_bg_color: 0.3, 0.3, 0.3, 1
                pos_hint: {"center_y": .5}
                on_release: app.adjust_active_timer(-15)

                MDButtonText:
                    text: "- 15s"

            MDLabel:
                id: timer_display
                text: "00 : 00"
                font_style: "Headline"
                role: "small"
                halign: "center"
                theme_text_color: "Custom"
                text_color: 1, 1, 1, 1
                
            MDButton:
                style: "filled"
                md_bg_color: 0.3, 0.3, 0.3, 1
                pos_hint: {"center_y": .5}
                on_release: app.adjust_active_timer(15)

                MDButtonText:
                    text: "+ 15s"
                
            MDButton:
                style: "filled"
                md_bg_color: 0.8, 0.2, 0.2, 1
                pos_hint: {"center_y": .5}
                on_release: app.stop_timer(skip=True)

                MDButtonText:
                    text: "SALTA"
                    theme_text_color: "Custom"
                    text_color: 1, 1, 1, 1
'''

class CourtStrengthApp(MDApp):
    def build(self):
        self.theme_cls.theme_style = "Dark"
        self.timer_event = None
        self.time_left = 0
        self.current_block_active = None
        
        Builder.load_string(KV)
        self.sm = WindowManager()
        self.load_home_data()
        return self.sm

    def load_home_data(self):
        try:
            with open('workouts.json', 'r') as f:
                data = json.load(f)
                workouts = data.get('workouts', [])
            
            home_screen = self.sm.get_screen('home')
            workout_list = home_screen.ids.workout_list
            
            for workout in workouts:
                mins = workout.get('duration_minutes', 60)
                count = workout.get('exercises_count', len(workout.get('exercises', [])))
                
                # Creiamo la nuova Card per la Home
                card = WorkoutListCard(
                    workout_data=workout,
                    title_text=workout.get('title', ''),
                    subtitle_text=workout.get('subtitle', '').upper(),
                    stats_text=f"{mins} MIN   |   {count} ESERCIZI"
                )
                workout_list.add_widget(card)
                
        except Exception as e:
            print(f"Errore lettura JSON: {e}")

    def start_workout(self, workout):
        ws = self.sm.get_screen('workout').ids
        ws.workout_title.text = workout['title']
        ws.workout_subtitle.text = workout['subtitle'].upper()
        ws.workout_desc.text = workout.get('description', '')
        mins = workout.get('duration_minutes', 60)
        count = workout.get('exercises_count', len(workout.get('exercises', [])))
        ws.workout_stats.text = f"{mins} MIN   |   {count} ESERCIZI"
        
        container = ws.exercises_container
        container.clear_widgets()
        
        exercises = workout.get('exercises', [])
        
        colors = {
            "A": [0.8, 1, 0.2, 1],
            "B": [0.2, 0.8, 1, 1],
            "C": [1, 0.6, 0.2, 1],
            "DEFAULT": [0.9, 0.9, 0.9, 1]
        }

        for i, ex in enumerate(exercises):
            category = ex.get('category', '').upper()
            
            match = re.search(r'\(([A-Z])\d+\)', category)
            block_letter = match.group(1) if match else f"SINGLE_{i}"
            theme_color = colors.get(block_letter, colors["DEFAULT"]) if len(block_letter) == 1 else colors["DEFAULT"]
            
            is_last = True
            if i + 1 < len(exercises):
                next_category = exercises[i+1].get('category', '').upper()
                next_match = re.search(r'\(([A-Z])\d+\)', next_category)
                next_block = next_match.group(1) if next_match else f"SINGLE_{i+1}"
                
                if len(block_letter) == 1 and block_letter == next_block:
                    is_last = False

            card = ExerciseCard(
                block_id=block_letter,
                category=category,
                name_ex=ex.get('name', ''),
                desc=ex.get('description', ''),
                target_sets=ex.get('sets', 0),
                current_set=0,
                reps_str=str(ex.get('reps', '')),
                weight=ex.get('weight_kg', 0),
                rest_time=ex.get('rest_seconds', 0),
                color_theme=theme_color,
                is_last_in_block=is_last
            )
            container.add_widget(card)
        
        self.sm.current = 'workout'

    def go_home(self):
        self.sm.current = 'home'
        self.stop_timer(skip=False)

    def next_in_superset(self):
        self.show_message(
            "Superset in corso: passa subito al prossimo esercizio!"
        )

    def show_message(self, message, duration=1.5):
        popup = Popup(
            title="CourtStrength",
            content=Label(
                text=message,
                halign="center",
                valign="middle",
                padding=(dp(12), dp(12)),
            ),
            size_hint=(0.85, None),
            height=dp(120),
            auto_dismiss=False,
        )
        popup.content.bind(size=lambda instance, value: setattr(instance, "text_size", value))
        popup.open()
        Clock.schedule_once(lambda dt: popup.dismiss(), duration)

    def start_timer(self, seconds, block_id):
        if self.timer_event:
            self.timer_event.cancel()
        
        self.current_block_active = block_id
        self.time_left = seconds
        self.update_timer_display()
        self.timer_event = Clock.schedule_interval(self.tick, 1)

    def adjust_active_timer(self, amount):
        if self.timer_event:
            self.time_left += amount
            if self.time_left < 0:
                self.time_left = 0
            self.update_timer_display()

    def stop_timer(self, skip=False):
        if self.timer_event:
            self.timer_event.cancel()
            self.time_left = 0
            self.update_timer_display()
            if skip:
                self.complete_rest_for_block()

    def tick(self, dt):
        self.time_left -= 1
        self.update_timer_display()
        
        if self.time_left <= 0:
            self.timer_event.cancel()
            self.complete_rest_for_block()

    def complete_rest_for_block(self):
        if self.current_block_active:
            container = self.sm.get_screen('workout').ids.exercises_container
            for child in container.children:
                if isinstance(child, ExerciseCard) and child.block_id == self.current_block_active:
                    child.current_set += 1
            
            self.current_block_active = None
            self.show_message(
                "Recupero Terminato! Serie aggiunta. Torna in posizione."
            )

    def update_timer_display(self):
        mins, secs = divmod(self.time_left, 60)
        self.sm.get_screen('workout').ids.timer_display.text = f"{mins:02d} : {secs:02d}"

if __name__ == '__main__':
    CourtStrengthApp().run()