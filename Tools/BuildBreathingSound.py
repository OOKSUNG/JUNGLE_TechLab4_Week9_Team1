import math as Math
import random as Random
import sys as Sys
import wave as Wave
from array import array as Array
from pathlib import Path


SampleRate = 44100
BreathingFrequency = 0.65
CycleCount = 4


def FilterBand(Noise, Frequency, Quality):
    Angle = 2.0 * Math.pi * Frequency / SampleRate
    Alpha = Math.sin(Angle) / (2.0 * Quality)
    Numerator = Alpha / (1.0 + Alpha)
    FeedbackFirst = -2.0 * Math.cos(Angle) / (1.0 + Alpha)
    FeedbackSecond = (1.0 - Alpha) / (1.0 + Alpha)
    PreviousInput = 0.0
    OlderInput = 0.0
    PreviousOutput = 0.0
    OlderOutput = 0.0
    Filtered = []
    for Value in Noise:
        Output = Numerator * (Value - OlderInput) - FeedbackFirst * PreviousOutput - FeedbackSecond * OlderOutput
        Filtered.append(Output)
        OlderInput = PreviousInput
        PreviousInput = Value
        OlderOutput = PreviousOutput
        PreviousOutput = Output
    return Filtered


def Envelope(Phase, Start, Duration):
    Progress = (Phase - Start) / Duration
    if Progress <= 0.0 or Progress >= 1.0:
        return 0.0
    return Math.sin(Math.pi * Progress) ** 1.4 * (1.0 - 0.35 * Progress)


def BuildSound():
    FrameCount = round(CycleCount * SampleRate / BreathingFrequency)
    Generator = Random.Random(2047)
    Noise = [Generator.uniform(-1.0, 1.0) for Index in range(FrameCount)]
    LowBand = FilterBand(Noise, 390.0, 0.65)
    MiddleBand = FilterBand(Noise, 1050.0, 0.8)
    HighBand = FilterBand(Noise, 2450.0, 0.7)
    Variations = (0.96, 1.03, 0.99, 1.02)
    Samples = []
    ThroatPhase = 0.0
    for Index in range(FrameCount):
        Time = Index / SampleRate
        Cycle = Index * CycleCount / FrameCount
        Phase = Cycle % 1.0
        Inhale = Envelope(Phase, 0.01, 0.35) * 0.78
        Exhale = Envelope(Phase, 0.43, 0.43)
        Air = Inhale * (0.28 * LowBand[Index] + 0.75 * MiddleBand[Index] + 0.45 * HighBand[Index]) + Exhale * (0.85 * LowBand[Index] + 0.56 * MiddleBand[Index] + 0.13 * HighBand[Index])
        Flutter = 0.87 + 0.08 * Math.sin(2.0 * Math.pi * 24.0 * Time) + 0.05 * Math.sin(2.0 * Math.pi * 39.0 * Time)
        ThroatPhase += 2.0 * Math.pi * (118.0 + 7.0 * Math.sin(2.0 * Math.pi * Phase)) / SampleRate
        Throat = (Math.sin(ThroatPhase) + 0.3 * Math.sin(ThroatPhase * 2.0)) * 0.018 * Exhale
        Samples.append((Air * Flutter + Throat) * Variations[int(Cycle)])
    Peak = max(abs(Value) for Value in Samples)
    Frames = Array("h", (round(Value / Peak * 0.88 * 32767) for Value in Samples))
    if Sys.byteorder != "little":
        Frames.byteswap()
    return Frames


def Main():
    Target = Path(__file__).resolve().parents[1] / "Assets/Sounds/RecoveryBreathing.wav"
    Frames = BuildSound()
    with Wave.open(str(Target), "wb") as Sound:
        Sound.setnchannels(1)
        Sound.setsampwidth(2)
        Sound.setframerate(SampleRate)
        Sound.writeframes(Frames.tobytes())
    print(f"Created {Target.name}: {len(Frames) / SampleRate:.3f}s, mono {SampleRate} Hz, 16-bit PCM")


if __name__ == "__main__":
    Main()
