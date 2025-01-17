/*
    ,--.                     ,--.     ,--.  ,--.
  ,-'  '-.,--.--.,--,--.,---.|  |,-.,-'  '-.`--' ,---. ,--,--,      Copyright 2024
  '-.  .-'|  .--' ,-.  | .--'|     /'-.  .-',--.| .-. ||      \   Tracktion Software
    |  |  |  |  \ '-'  \ `--.|  \  \  |  |  |  |' '-' '|  ||  |       Corporation
    `---' `--'   `--`--'`---'`--'`--' `---' `--' `---' `--''--'    www.tracktion.com

    Tracktion Engine uses a GPL/commercial licence - see LICENCE.md for details.
*/

namespace tracktion { inline namespace engine
{

/**
    A Node that introduces latency to balance the latency at the root Node and its position in the graph.
*/
class LevelMeasurerProcessingNode final : public tracktion::graph::Node
{
public:
    LevelMeasurerProcessingNode (std::unique_ptr<tracktion::graph::Node> inputNode, LevelMeterPlugin& levelMeterPlugin)
        : input (std::move (inputNode)),
          meterPlugin (levelMeterPlugin)
    {
    }

    ~LevelMeasurerProcessingNode() override
    {
        if (isInitialised && ! meterPlugin.baseClassNeedsInitialising())
            meterPlugin.baseClassDeinitialise();
    }

    tracktion::graph::NodeProperties getNodeProperties() override
    {
        auto props = input->getNodeProperties();

        if (props.nodeID != 0)
        {
            hash_combine (props.nodeID, static_cast<size_t> (meterPlugin.itemID.getRawID()));
            hash_combine (props.nodeID, static_cast<size_t> (3731138684616245860)); // LevelMeasurerProcessingNode
        }

        return props;
    }

    std::vector<tracktion::graph::Node*> getDirectInputNodes() override
    {
        return { input.get() };
    }

    bool isReadyToProcess() override
    {
        return input->hasProcessed();
    }

    void prepareToPlay (const tracktion::graph::PlaybackInitialisationInfo& info) override
    {
        initialisePlugin();

        const auto inputProps = input->getNodeProperties();
        const auto nodeProps = getNodeProperties();

        if (info.enableNodeMemorySharing && input->numOutputNodes == 1)
        {
            const auto inputNumChannels = inputProps.numberOfChannels;
            const auto desiredNumChannels = nodeProps.numberOfChannels;

            if (inputNumChannels >= desiredNumChannels)
            {
                canUseSourceBuffers = true;
                setOptimisations ({ tracktion::graph::ClearBuffers::no,
                                    tracktion::graph::AllocateAudioBuffer::no });
            }
        }

        const int latencyAtRoot = info.nodeGraph.rootNode->getNodeProperties().latencyNumSamples;
        const int latencyAtInput = inputProps.latencyNumSamples;

        const int numSamplesLatencyToIntroduce = latencyAtRoot - latencyAtInput;

        if (numSamplesLatencyToIntroduce <= 0)
            return;

        latencyProcessor = std::make_shared<tracktion::graph::LatencyProcessor>();
        latencyProcessor->setLatencyNumSamples (numSamplesLatencyToIntroduce);
        latencyProcessor->prepareToPlay (info.sampleRate, info.blockSize, nodeProps.numberOfChannels);

        tempAudioBuffer.resize ({ (choc::buffer::ChannelCount) nodeProps.numberOfChannels,
                                  (choc::buffer::FrameCount) info.blockSize });
    }

    void preProcess (choc::buffer::FrameCount, juce::Range<int64_t>) override
    {
        if (canUseSourceBuffers)
            setBufferViewToUse (input.get(), input->getProcessedOutput().audio);
    }

    void process (ProcessContext& pc) override
    {
        // Copy the input buffers to the outputs without applying latency
        auto sourceBuffers = input->getProcessedOutput();
        jassert (sourceBuffers.audio.getNumChannels() == pc.buffers.audio.getNumChannels());

        // If the source only outputs to this node, we can steal its data
        if (input->numOutputNodes == 1)
        {
            pc.buffers.midi.swapWith (sourceBuffers.midi);
            setAudioOutput (input.get(), sourceBuffers.audio);
        }
        else
        {
            pc.buffers.midi.copyFrom (sourceBuffers.midi);
            copyIfNotAliased (pc.buffers.audio, sourceBuffers.audio);
        }

        // If we have no latency, simply process the meter
        if (! latencyProcessor)
        {
            processLevelMeasurer (meterPlugin.measurer, sourceBuffers.audio, pc.buffers.midi);
            return;
        }

        // Otherwise, pass the buffers through the latency processor and process the meter
        const auto numFrames = sourceBuffers.audio.getNumFrames();

        latencyProcessor->writeAudio (sourceBuffers.audio);
        latencyProcessor->writeMIDI (sourceBuffers.midi);

        tempMidiBuffer.clear();

        auto tempBlock = tempAudioBuffer.getStart (numFrames);
        latencyProcessor->readAudioOverwriting (tempBlock);
        latencyProcessor->readMIDI (tempMidiBuffer, (int) numFrames);

        processLevelMeasurer (meterPlugin.measurer, tempBlock, tempMidiBuffer);
    }

private:
    std::unique_ptr<tracktion::graph::Node> input;
    LevelMeterPlugin& meterPlugin;
    Plugin::Ptr pluginPtr { meterPlugin };
    bool isInitialised = false, canUseSourceBuffers = false;

    std::shared_ptr<tracktion::graph::LatencyProcessor> latencyProcessor;

    choc::buffer::ChannelArrayBuffer<float> tempAudioBuffer;
    MidiMessageArray tempMidiBuffer;

    //==============================================================================
    void initialisePlugin()
    {
        // N.B. This is deliberately zeroed as it (correctly) assumes the LevelMeterPlugin doesn't need the info during initialisation
        meterPlugin.baseClassInitialise ({ 0_tp, 0.0, 0 });
        isInitialised = true;
    }

    void processLevelMeasurer (LevelMeasurer& measurer, choc::buffer::ChannelArrayView<float> block, MidiMessageArray& midi)
    {
        auto buffer = tracktion::graph::toAudioBuffer (block);
        measurer.processBuffer (buffer, 0, buffer.getNumSamples());

        measurer.setShowMidi (meterPlugin.showMidiActivity);
        measurer.processMidi (midi, nullptr);
    }
};

}} // namespace tracktion { inline namespace engine
