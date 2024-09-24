package moonchart.formats;

import moonchart.backend.FormatData;
import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.StepManiaSharkParser;
import moonchart.formats.StepMania.StepManiaBasic;

// Extension of StepMania
class StepManiaShark extends StepManiaBasic<SSCFormat>
{
	public static function __getFormat():FormatData
	{
		return {
			ID: STEPMANIA_SHARK,
			name: "StepManiaShark",
			description: "",
			extension: "ssc",
			hasMetaFile: FALSE,
			handler: StepManiaShark
		}
	}

	public function new(?data:SSCFormat)
	{
		super(data);
		this.data = data;
		parser = new StepManiaSharkParser();
	}

	// Mark labels as events cus that makes it usable for shit like FNF
	override function getEvents():Array<BasicEvent>
	{
		var events = super.getEvents();
		var bpmChanges = getChartMeta().bpmChanges;

		var labels = data.LABELS.copy();

		var lastTime:Float = 0;
		var lastBeat:Float = 0;
		var crochet:Float = Timing.crochet(bpmChanges.shift().bpm);

		// Add labels between bpm changes
		for (change in bpmChanges)
		{
			var elapsedTime:Float = change.time - lastTime;
			var curBeat = lastBeat + (elapsedTime * crochet);

			while (labels.length > 0 && labels[0].beat <= curBeat)
			{
				var label = labels.shift();
				events.push({
					time: change.time + ((label.beat - curBeat) * crochet),
					name: label.label,
					data: {}
				});
			}

			crochet = Timing.crochet(change.bpm);
			lastTime = change.time;
			lastBeat = curBeat;
		}

		// Add any left over labels
		while (labels.length > 0)
		{
			var label = labels.shift();
			events.push({
				time: lastTime + ((label.beat - lastBeat) * crochet),
				name: label.label,
				data: {}
			});
		}

		return events;
	}

	override function getChartMeta():BasicMetaData // sobbing uncontrollably
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		var time:Float = 0;
		var lastBeat:Float = 0;
		var lastBPM:Float = data.BPMS[0].bpm;
		var lastDenominator:Int = 4;

		var timeSignatures:Array<SSCTimeSignature> = data.TIMESIGNATURES; // absolutely deranged
		var activeSignature:SSCTimeSignature = null;
		var nextSignature:Int = 0;
		if (timeSignatures.length > 0 && timeSignatures[0].beat == 0) {
			activeSignature = timeSignatures[0];
			nextSignature ++;
		}

		bpmChanges.push({
			time: 0,
			bpm: lastBPM,
			beatsPerMeasure: activeSignature?.numerator ?? 4,
			stepsPerBeat: activeSignature?.denominator ?? 4
		});

		// Convert the bpm changes from beats to milliseconds
		for (i in 1...data.BPMS.length)
		{
			var change = data.BPMS[i];
			while (nextSignature < timeSignatures.length && change.beat >= timeSignatures[nextSignature].beat) {
				activeSignature = timeSignatures[nextSignature];
				time += ((activeSignature.beat - lastBeat) / lastBPM) * 60000 * (4 / lastDenominator);
				lastDenominator = activeSignature.denominator;
				if (change.beat > activeSignature.beat) {
					bpmChanges.push({
						time: time,
						bpm: lastBPM,
						beatsPerMeasure: activeSignature.numerator,
						stepsPerBeat: activeSignature.denominator
					});
				}
				lastBeat = activeSignature.beat;
				nextSignature ++;
			}
			time += ((change.beat - lastBeat) / lastBPM) * 60000 * (4 / lastDenominator);

			lastBeat = change.beat;
			lastBPM = change.bpm;

			bpmChanges.push({
				time: time,
				bpm: lastBPM,
				beatsPerMeasure: activeSignature?.numerator ?? 4,
				stepsPerBeat: activeSignature?.denominator ?? 4
			});
		}
		if (nextSignature < timeSignatures.length) {
			for (i in nextSignature...timeSignatures.length) {
				var change = timeSignatures[i];
				time += ((change.beat - lastBeat) / lastBPM) * 60000 * (4 / lastDenominator);

				lastDenominator = change.denominator;
				lastBeat = change.beat;

				bpmChanges.push({
					time: time,
					bpm: lastBPM,
					beatsPerMeasure: change.numerator,
					stepsPerBeat: change.denominator
				});
			}
		}

		bpmChanges = Timing.sortBPMChanges(bpmChanges);

		// TODO: this may have to apply for bpm changes too, change scroll speed event?
		final speed:Float = bpmChanges[0].bpm * StepMania.STEPMANIA_SCROLL_SPEED;
		final offset:Float = data.OFFSET is String ? Std.parseFloat(cast data.OFFSET) : data.OFFSET;
		final isSingle:Bool = Util.mapFirst(data.NOTES).dance == SINGLE;

		return {
			title: data.TITLE,
			bpmChanges: bpmChanges,
			offset: offset * 1000,
			scrollSpeeds: Util.fillMap(diffs, speed),
			extraData: [SONG_ARTIST => data.ARTIST, LANES_LENGTH => isSingle ? 4 : 8]
		}
	}

	override public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):StepManiaShark
	{
		return fromStepManiaShark(Util.getText(path), diff);
	}

	public function fromStepManiaShark(data:String, ?diff:FormatDifficulty):StepManiaShark
	{
		this.data = parser.parse(data);
		this.diffs = diff ?? Util.mapKeyArray(this.data.NOTES);
		return this;
	}
}
